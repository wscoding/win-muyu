# -*- coding: utf-8 -*-
"""
============================================================
域名 DNSSEC 健康巡检
创建时间: 2026-09-23
名称: check_dnssec.py
作用: 批量体检一组域名的 DNSSEC 状态，专门抓这一类**静默故障**：
        注册局的 DS 记录与权威 DNSKEY 不匹配（算法/key tag/摘要对不上）
        → 所有做 DNSSEC 校验的公共 DNS 直接 SERVFAIL
        → 表现为「本机能打开、别人打不开」，极难排查。
      （2026-09-23 chr.cc 真实案例：DS 算法写成 8，DNSKEY 是算法 13，
        整个域名的所有子域 SERVFAIL 了不知道多久。）

      每个域名给出四件事：
        1) 是否启用了 DNSSEC（父区有没有 DS）
        2) 权威区是否签名（DNSKEY 是否存在）
        3) DS 与 DNSKEY 是否匹配（算法 + key tag）
        4) 校验型解析是否通过（ad 标志）

用法:
  python Scripts/check_dnssec.py                     # 用默认域名清单
  python Scripts/check_dnssec.py chr.cc s2ss.com      # 指定域名
  python Scripts/check_dnssec.py --strict             # 只要有问题就以非 0 退出（可挂监控）
依赖: paramiko
============================================================
"""
import base64
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote, log  # noqa: E402

# 默认体检清单：这台服务器上承载的各个域名族
DEFAULT_DOMAINS = [
    'chr.cc',
    's2ss.com',
    'wktyl.com',
    'vogov.cn',
    'xianyan.cc',
    'iqg.cc',
    'wyi.cc',
]

# 用于校验型查询的解析器（两个都查，避免单个解析器缓存误导）
RESOLVERS = ['1.1.1.1', '8.8.8.8']


def sh_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def key_tag(flags, protocol, algorithm, key_bytes):
    """按 RFC 4034 Appendix B 计算 DNSKEY 的 Key Tag"""
    rdata = struct.pack('!HBB', flags, protocol, algorithm) + key_bytes
    acc = 0
    for i, byte in enumerate(rdata):
        acc += byte << (8 if i % 2 == 0 else 0)
    acc += (acc >> 16) & 0xFFFF
    return acc & 0xFFFF


def ds_digest(owner, flags, protocol, algorithm, key_bytes, digest_type=2):
    """按 RFC 4034 计算 DS 摘要（type 1=SHA1 / 2=SHA256）"""
    import hashlib
    rdata = struct.pack('!HBB', flags, protocol, algorithm) + key_bytes
    wire_owner = b''
    for label in owner.rstrip('.').split('.'):
        wire_owner += bytes([len(label)]) + label.encode('ascii')
    wire_owner += b'\x00'
    data = wire_owner + rdata
    if digest_type == 1:
        return hashlib.sha1(data).hexdigest().upper()
    return hashlib.sha256(data).hexdigest().upper()


def inspect(remote, domain):
    """返回该域名的体检结果字典"""
    result = {'domain': domain, 'ds': [], 'dnskey': [], 'validations': {}, 'errors': []}

    # 1) 父区的 DS（+cd 关闭校验，保证即使当前有问题也能读到数据）
    ok, out, _ = remote.run(
        "dig DS %s @%s +cd +noall +answer" % (domain, RESOLVERS[0]), timeout=60)
    for line in out.splitlines():
        parts = line.split()
        # chr.cc. 86400 IN DS 2371 13 2 E4CDAA...
        if 'DS' in parts:
            idx = parts.index('DS')
            fields = parts[idx + 1:]
            if len(fields) >= 4:
                result['ds'].append({
                    'key_tag': int(fields[0]),
                    'algorithm': int(fields[1]),
                    'digest_type': int(fields[2]),
                    'digest': fields[3].replace(' ', '').upper(),
                })

    # 2) 权威区的 DNSKEY
    ok, ns_out, _ = remote.run("dig +short NS %s" % domain, timeout=60)
    nameservers = [n.strip().rstrip('.') for n in ns_out.splitlines() if n.strip()]
    result['nameservers'] = nameservers
    if nameservers:
        ok, out, _ = remote.run(
            "dig DNSKEY %s @%s +noall +answer" % (domain, nameservers[0]), timeout=60)
        for line in out.splitlines():
            parts = line.split()
            if 'DNSKEY' in parts:
                idx = parts.index('DNSKEY')
                fields = parts[idx + 1:]
                if len(fields) >= 4:
                    flags, protocol, algorithm = int(fields[0]), int(fields[1]), int(fields[2])
                    key_b64 = ''.join(fields[3:])
                    try:
                        key_bytes = base64.b64decode(key_b64)
                    except Exception:  # noqa: BLE001
                        continue
                    result['dnskey'].append({
                        'flags': flags,
                        'protocol': protocol,
                        'algorithm': algorithm,
                        'key_tag': key_tag(flags, protocol, algorithm, key_bytes),
                        'is_ksk': flags == 257,
                        'key_bytes': key_bytes,
                    })

    # 3) 校验型解析结果
    for resolver in RESOLVERS:
        ok, out, _ = remote.run(
            "dig +dnssec %s @%s 2>&1 | grep -E 'status:|flags:' | head -2" % (domain, resolver),
            timeout=60)
        status = re.search(r'status: (\w+)', out)
        ad = ' ad' in out or ' ad;' in out
        result['validations'][resolver] = {
            'status': status.group(1) if status else 'UNKNOWN',
            'ad': ad,
        }

    return result


def judge(result):
    """判定体检结论。返回 (等级, 说明)；等级 ∈ ok / warn / fail / off"""
    ds_list = result['ds']
    keys = result['dnskey']
    validations = result['validations']

    all_ok = all(v['status'] == 'NOERROR' and v['ad'] for v in validations.values())
    any_servfail = any(v['status'] == 'SERVFAIL' for v in validations.values())

    if not ds_list:
        if all_ok:
            return 'off', '未启用 DNSSEC（解析正常）'
        if any_servfail:
            return 'fail', '没有 DS 却出现 SERVFAIL —— 上游或权威异常，需单独排查'
        return 'warn', '未启用 DNSSEC（解析状态：%s）' % validations[RESOLVERS[0]]['status']

    if not keys:
        return 'fail', '父区有 DS，但权威区没有 DNSKEY（区未签名）→ 校验必然失败'

    # 逐个 DS 找匹配的 DNSKEY（算法 + key tag 都要对上）
    unmatched = []
    matched = []
    for ds in ds_list:
        hit = [k for k in keys
               if k['algorithm'] == ds['algorithm'] and k['key_tag'] == ds['key_tag']]
        if hit:
            matched.append((ds, hit[0]))
        else:
            unmatched.append(ds)

    if unmatched:
        detail = []
        for ds in unmatched:
            detail.append(
                'DS(keyTag=%d, algo=%d) 在权威 DNSKEY 中找不到对应密钥'
                % (ds['key_tag'], ds['algorithm']))
            # 帮用户指出「是不是算法填错了」
            same_tag = [k for k in keys if k['key_tag'] == ds['key_tag']]
            if same_tag:
                detail.append('  ↳ 但存在 keyTag 相同、算法为 %d 的 DNSKEY —— 很可能是 DS 的算法字段填错'
                              % same_tag[0]['algorithm'])
            for k in keys:
                if k['is_ksk']:
                    correct = ds_digest(result['domain'], k['flags'], k['protocol'],
                                        k['algorithm'], k['key_bytes'], ds['digest_type'])
                    detail.append('  ↳ 该 KSK 正确的 DS 应为：%d %d %d %s'
                                  % (k['key_tag'], k['algorithm'], ds['digest_type'], correct))
                    break
        return 'fail', '；'.join(detail)

    if any_servfail:
        return 'fail', 'DS 与 DNSKEY 匹配，但校验解析仍 SERVFAIL（可能注册局未生效或缓存未过期）'

    if all_ok:
        return 'ok', 'DNSSEC 正常（%d 条 DS 全部匹配，校验通过）' % len(ds_list)

    return 'warn', 'DS 与 DNSKEY 匹配，但部分解析器未返回 ad 标志'


def main():
    args = sys.argv[1:]
    strict = '--strict' in args
    domains = [a for a in args if not a.startswith('-')] or DEFAULT_DOMAINS

    remote = Remote()
    problems = 0
    try:
        log('=' * 66)
        log('DNSSEC 健康巡检（%d 个域名）' % len(domains))
        log('=' * 66)
        for domain in domains:
            try:
                result = inspect(remote, domain)
                level, message = judge(result)
            except Exception as exc:  # noqa: BLE001
                level, message, result = 'fail', '巡检异常：%s' % exc, {'nameservers': []}

            icon = {'ok': '✅', 'off': '○', 'warn': '⚠️ ', 'fail': '❌'}[level]
            print('%s %-14s %s' % (icon, domain, message))
            if level == 'fail':
                problems += 1
            if result.get('ds'):
                for ds in result['ds']:
                    print('     DS: keyTag=%d algo=%d digest=%s…'
                          % (ds['key_tag'], ds['algorithm'], ds['digest'][:24]))
            if level in ('warn', 'fail'):
                for resolver, state in (result.get('validations') or {}).items():
                    print('     @%-12s status=%s ad=%s'
                          % (resolver, state['status'], state['ad']))
            print()
        log('=' * 66)
        if problems:
            log('发现 %d 个域名的 DNSSEC 配置有问题' % problems, 'ERROR')
            if strict:
                sys.exit(1)
        else:
            log('全部域名 DNSSEC 状态正常（或未启用）')
        log('=' * 66)
    finally:
        remote.close()


if __name__ == '__main__':
    main()
