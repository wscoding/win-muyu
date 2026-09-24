# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 数据库初始化
创建时间: 2026-09-23
名称: init_wid_db.py
作用: 在主服务器 MySQL 5.7 上创建独立库 wid 与用户 wid（沿用本站
      「密码==用户名」约定，仅授权 127.0.0.1 / localhost），导入
      app/schema.sql 与 app/seed.sql，并确保默认应用记录存在。
      最后把生成的凭据写入 Scripts/.wid_secrets.json 供部署脚本复用。
特性: 全程幂等 —— 库、用户、表、种子数据、应用记录都可重复执行。
用法:
  python Scripts/init_wid_db.py                 # 全量执行
  python Scripts/init_wid_db.py --show-secret   # 只打印当前 app_key / app_secret
  python Scripts/init_wid_db.py --drop          # 危险：删除 wid 库后重建（需二次确认）
依赖: paramiko（venv: C:/Users/无书/.workbuddy/binaries/python/envs/default）
============================================================
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import widlib  # noqa: E402
from widlib import Remote, STAGING_ROOT, log  # noqa: E402

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(BASE), 'src')
SECRETS_FILE = os.path.join(BASE, '.wid_secrets.json')

DB_NAME = 'wid'
DB_USER = 'wid'
DB_PASS = 'wid'          # 站点库约定：密码 == 用户名（见服务器交接文档）
MYSQL_ROOT_PASS = '258051'

APP_KEY = '8f23f05b4a50b6481ff020320692f9e9'   # 与客户端 AppConfig.appKey 保持一致
APP_NAME = 'Prue Widgets 桌面端'


def mysql(sql, database=None):
    """在服务器上以 root 执行 SQL，返回 (ok, stdout, stderr)

    --default-character-set=utf8mb4 必须显式指定：客户端默认是 utf8（三字节），
    写入 emoji 等四字节字符会被截断或乱码。
    """
    db_arg = ' ' + database if database else ''
    cmd = "mysql --default-character-set=utf8mb4 -uroot -p'%s'%s -e %s 2>&1" % (
        MYSQL_ROOT_PASS, db_arg, shell_quote(sql))
    code, out, err = _REMOTE.run(cmd)
    return code == 0, out, err


def mysql_file(remote_path, database=None):
    db_arg = ' ' + database if database else ''
    cmd = "mysql --default-character-set=utf8mb4 -uroot -p'%s'%s < %s 2>&1" % (
        MYSQL_ROOT_PASS, db_arg, remote_path)
    return _REMOTE.run(cmd)


def shell_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def load_secrets():
    if os.path.isfile(SECRETS_FILE):
        try:
            with open(SECRETS_FILE, 'r', encoding='utf-8') as fh:
                return json.load(fh)
        except Exception:  # noqa: BLE001
            pass
    return {}


def save_secrets(data):
    with open(SECRETS_FILE, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
    log('凭据已写入 %s（请勿提交到版本库）' % SECRETS_FILE)


def ensure_database():
    log('创建库与用户（幂等）…')
    mysql("CREATE DATABASE IF NOT EXISTS `%s` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" % DB_NAME)
    for host in ('127.0.0.1', 'localhost'):
        mysql("CREATE USER IF NOT EXISTS '%s'@'%s' IDENTIFIED BY '%s';" % (DB_USER, host, DB_PASS))
        mysql("ALTER USER '%s'@'%s' IDENTIFIED BY '%s';" % (DB_USER, host, DB_PASS))
        mysql("GRANT ALL PRIVILEGES ON `%s`.* TO '%s'@'%s';" % (DB_NAME, DB_USER, host))
    mysql("FLUSH PRIVILEGES;")

    ok, out, _ = mysql("SHOW DATABASES LIKE '%s';" % DB_NAME)
    log('库存在：%s' % ('是' if DB_NAME in out else '否'))


def import_sql(local_rel, label):
    local_path = os.path.join(SRC, 'app', local_rel)
    if not os.path.isfile(local_path):
        log('缺少 %s，跳过' % local_rel, 'WARN')
        return False
    remote_path = STAGING_ROOT + '/' + os.path.basename(local_rel)
    _REMOTE.put(local_path, remote_path)
    code, out, err = mysql_file(remote_path, DB_NAME)
    if code != 0:
        log('%s 导入失败：%s' % (label, (err or out).strip()[:400]), 'ERROR')
        return False
    log('%s 导入完成' % label)
    return True


def ensure_app():
    """确保默认应用存在；不存在则生成密钥并写入本地凭据文件"""
    ok, out, _ = mysql(
        "SELECT CONCAT(app_key, '|', app_secret) FROM apps WHERE app_key='%s' LIMIT 1;" % APP_KEY,
        DB_NAME)
    row = ''
    for line in out.splitlines():
        line = line.strip()
        if line and '|' in line:
            row = line
            break
    if row:
        app_key, app_secret = row.split('|', 1)
        log('默认应用已存在：app_key=%s' % app_key)
    else:
        import secrets
        app_secret = secrets.token_hex(32)
        mysql(
            "INSERT INTO apps (app_key, app_secret, name, status, rate_limit_per_min, request_total, note, created_at, updated_at) "
            "VALUES ('%s', '%s', '%s', 1, 900, 0, '初始化脚本创建', NOW(), NOW());" % (APP_KEY, app_secret, APP_NAME),
            DB_NAME)
        app_key = APP_KEY
        log('已创建默认应用（新密钥已生成）')

    mysql("INSERT IGNORE INTO global_stats (app_id, launches, taps, merit, online_now, online_peak, updated_at) "
          "SELECT id, 0, 0, 0, 0, 0, NOW() FROM apps WHERE app_key='%s';" % APP_KEY, DB_NAME)

    data = load_secrets()
    data.update({
        'db_name': DB_NAME,
        'db_user': DB_USER,
        'db_pass': DB_PASS,
        'app_key': app_key,
        'app_secret': app_secret,
    })
    save_secrets(data)
    return app_key, app_secret


def show_secret():
    data = load_secrets()
    if not data.get('app_key'):
        log('本地没有凭据文件，请先执行一次完整初始化', 'ERROR')
        return
    print('app_key    :', data.get('app_key'))
    print('app_secret :', data.get('app_secret'))
    print('db         :', '%s / %s / %s' % (data.get('db_name'), data.get('db_user'), data.get('db_pass')))


def verify():
    log('校验表数量与关键数据 …')
    ok, out, _ = mysql(
        "SELECT CONCAT('tables=', COUNT(*)) FROM information_schema.tables WHERE table_schema='%s';" % DB_NAME)
    print('  ', out.strip())
    ok, out, _ = mysql(
        "SELECT CONCAT('blessings=', (SELECT COUNT(*) FROM blessings), "
        "'  config=', (SELECT COUNT(*) FROM app_config), "
        "'  releases=', (SELECT COUNT(*) FROM app_releases), "
        "'  changelog=', (SELECT COUNT(*) FROM changelog_entries));", DB_NAME)
    print('  ', out.strip())


_REMOTE = None


def main():
    global _REMOTE
    args = sys.argv[1:]
    if '--show-secret' in args:
        show_secret()
        return

    if '--drop' in args:
        answer = input('⚠️  这会删除整个 wid 库及其全部数据，输入 DROP 以确认：')
        if answer.strip() != 'DROP':
            print('已取消')
            return

    _REMOTE = Remote()
    try:
        log('=' * 58)
        log('wid.chr.cc 数据库初始化 @ %s:%s' % (widlib.HOST, widlib.PORT))
        log('=' * 58)

        if '--drop' in args:
            mysql('DROP DATABASE IF EXISTS `%s`;' % DB_NAME)
            log('已删除旧库')

        ensure_database()

        if not import_sql('schema.sql', '表结构 schema.sql'):
            log('表结构导入失败，中止', 'ERROR')
            sys.exit(1)
        if not import_sql('seed.sql', '种子数据 seed.sql'):
            log('种子数据导入失败（非致命，继续）', 'WARN')

        ensure_app()
        verify()

        log('=' * 58)
        log('初始化完成。下一步执行：python Scripts/deploy_wid_site.py')
        log('=' * 58)
    finally:
        _REMOTE.close()


if __name__ == '__main__':
    main()
