/* ============================================================
   wid.chr.cc 管理后台脚本
   原生 JS + fetch，无框架、无构建。所有数据来自 admin/api.php。
   ============================================================ */
(function () {
  'use strict';

  var meta = document.querySelector('meta[name="csrf"]');
  var CSRF = meta ? meta.getAttribute('content') : '';
  var OPTIONS = { versions: [], platforms: [], channels: [], kinds: [], feedback_categories: [] };

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function esc(v) {
    if (v === null || v === undefined) return '';
    return String(v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function num(n) { return (Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }

  function fmtShort(n) {
    n = Number(n) || 0;
    if (n >= 100000000) return (n / 100000000).toFixed(2).replace(/\.?0+$/, '') + '亿';
    if (n >= 10000) return (n / 10000).toFixed(1).replace(/\.?0+$/, '') + '万';
    return num(n);
  }

  function bytes(n) {
    n = Number(n);
    if (!n || n <= 0) return '—';
    var u = ['B', 'KB', 'MB', 'GB'], i = 0;
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return (i === 0 ? n : n.toFixed(1)) + ' ' + u[i];
  }

  function notify(msg, type) {
    var box = $('#notify');
    box.className = 'admin-notify ' + (type === false ? 'err' : 'ok');
    box.textContent = msg;
    box.hidden = false;
    clearTimeout(notify._t);
    notify._t = setTimeout(function () { box.hidden = true; }, 3600);
  }

  /* ---------- 统一请求 ---------- */
  function api(action, data, opts) {
    opts = opts || {};
    var payload = Object.assign({ action: action }, data || {});
    return fetch('api.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF': CSRF, 'Accept': 'application/json' },
      body: JSON.stringify(payload)
    }).then(function (r) {
      return r.json().then(function (res) {
        if (r.status === 401) {
          notify('登录已过期，请重新登录', false);
          setTimeout(function () { location.reload(); }, 1200);
          throw new Error(res.msg || '登录已过期');
        }
        if (!res.ok) {
          notify(res.msg || '操作失败', false);
          throw new Error(res.msg || '操作失败');
        }
        if (!opts.silent) notify(res.msg || '操作成功');
        return res.data;
      });
    });
  }

  /* ---------- 小组件 ---------- */
  function statCard(label, value, foot) {
    return '<div class="stat"><div class="label">' + esc(label) + '</div>'
      + '<div class="value">' + esc(value) + '</div>'
      + (foot ? '<div class="foot">' + esc(foot) + '</div>' : '') + '</div>';
  }

  function bars(series, primaryKey, secondaryKey) {
    if (!series || !series.length) return '<div class="empty">暂无数据</div>';
    var maxP = 1, maxS = 1;
    series.forEach(function (r) {
      maxP = Math.max(maxP, Number(r[primaryKey]) || 0);
      if (secondaryKey) maxS = Math.max(maxS, Number(r[secondaryKey]) || 0);
    });
    var cols = '', labels = '';
    series.forEach(function (r) {
      var p = Number(r[primaryKey]) || 0;
      var s = secondaryKey ? (Number(r[secondaryKey]) || 0) : 0;
      var inner = '';
      if (secondaryKey) {
        inner += '<div class="bar alt" style="height:' + Math.max(s > 0 ? 4 : 2, Math.round(s / maxS * 100))
          + '%" title="' + esc(r.date + ' 设备 ' + s) + '"></div>';
      }
      inner += '<div class="bar" style="height:' + Math.max(p > 0 ? 4 : 2, Math.round(p / maxP * 100))
        + '%" title="' + esc(r.date + ' 敲击 ' + p) + '"></div>';
      cols += '<div class="bar-col">' + inner + '</div>';
      labels += '<span>' + esc(r.date.slice(5)) + '</span>';
    });
    return '<div class="bars" style="height:140px">' + cols + '</div><div class="bar-x">' + labels + '</div>';
  }

  function options(list, selected, labels) {
    return (list || []).map(function (v) {
      var label = labels && labels[v] ? labels[v] : v;
      return '<option value="' + esc(v) + '"' + (String(selected) === String(v) ? ' selected' : '') + '>'
        + esc(label) + '</option>';
    }).join('');
  }

  function table(headers, rows, emptyText) {
    if (!rows.length) return '<div class="admin-table-wrap"><div class="empty">' + esc(emptyText || '暂无数据') + '</div></div>';
    var head = headers.map(function (h) { return '<th' + (h.num ? ' class="num"' : '') + '>' + esc(h.text) + '</th>'; }).join('');
    var body = rows.map(function (cells) {
      return '<tr>' + cells.map(function (c) {
        if (c && typeof c === 'object' && c.html !== undefined) return '<td>' + c.html + '</td>';
        return '<td>' + esc(c) + '</td>';
      }).join('') + '</tr>';
    }).join('');
    return '<div class="admin-table-wrap"><table><thead><tr>' + head + '</tr></thead><tbody>' + body + '</tbody></table></div>';
  }

  function reload() { return render(current); }

  /* ================= 概览 ================= */
  function renderOverview() {
    return api('overview', {}, { silent: true }).then(function (d) {
      var s = d.summary;
      var html = '<h2 class="admin-h">实时概览 <span class="admin-sub">数据每 60 秒自动刷新</span></h2>';
      html += '<div class="cards">'
        + statCard('当前在线', num(s.online), '窗口 ' + s.online_window + ' 秒')
        + statCard('今日活跃设备', num(s.today.devices), '今日启动 ' + num(s.today.launches))
        + statCard('累计敲击', fmtShort(s.taps), '功德 ' + fmtShort(s.merit))
        + statCard('累计启动', fmtShort(s.launches), '在线峰值 ' + num(s.online_peak))
        + statCard('设备总数', num(s.devices), '今日敲击 ' + num(s.today.taps))
        + statCard('待处理反馈', num(d.pending_feedback), '崩溃上报 ' + num(d.crashes))
        + '</div>';

      html += '<h2 class="admin-h">近 14 日趋势</h2><div class="admin-card">'
        + bars(d.trend, 'taps', 'devices') + '</div>';

      html += '<div class="admin-grid" style="margin-top:14px">';
      html += '<div class="admin-card"><h3>平台分布</h3>'
        + table([{ text: '平台' }, { text: '设备', num: true }, { text: '在线', num: true }],
          (d.platforms || []).map(function (p) {
            var on = (d.online_by_platform || []).filter(function (x) { return x.platform === p.platform; })[0];
            return [p.platform, num(p.devices), num(on ? on.online : 0)];
          }), '暂无数据') + '</div>';
      html += '<div class="admin-card"><h3>版本分布</h3>'
        + table([{ text: '版本' }, { text: '设备', num: true }],
          (d.versions || []).map(function (v) { return ['v' + (v.version || '未知'), num(v.devices)]; }), '暂无数据') + '</div>';
      html += '</div>';

      html += '<h2 class="admin-h">最近事件</h2>'
        + table([{ text: '时间' }, { text: '级别' }, { text: '事件' }, { text: '说明' }],
          (d.latest_events || []).map(function (e) {
            return [e.created_at, e.level, e.event, { html: '<td class="wrap">' + esc(e.message) + '</td>' }];
          }), '暂无事件');

      $('#panel-overview').innerHTML = html;
      return d;
    });
  }

  /* ================= 设备 ================= */
  var deviceState = { page: 1, platform: '', client_version: '', status: '', keyword: '' };

  function renderDevices() {
    var q = {
      page: deviceState.page, size: 30,
      platform: deviceState.platform, client_version: deviceState.client_version,
      status: deviceState.status, keyword: deviceState.keyword
    };
    return api('devices.list', q, { silent: true }).then(function (d) {
      var html = '<h2 class="admin-h">设备列表 <span class="admin-sub">共 ' + num(d.total) + ' 台</span></h2>';
      html += '<div class="admin-card"><div class="form-grid">'
        + '<div class="field"><label>平台</label><select id="dv-platform">'
        + '<option value="">全部</option>' + options(OPTIONS.platforms, deviceState.platform) + '</select></div>'
        + '<div class="field"><label>客户端版本</label><select id="dv-version">'
        + '<option value="">全部</option>' + options(OPTIONS.versions, deviceState.client_version) + '</select></div>'
        + '<div class="field"><label>状态</label><select id="dv-status">'
        + '<option value="">全部</option><option value="1"' + (deviceState.status === '1' ? ' selected' : '') + '>正常</option>'
        + '<option value="0"' + (deviceState.status === '0' ? ' selected' : '') + '>封禁</option></select></div>'
        + '<div class="field"><label>设备标识关键词</label><input type="text" id="dv-keyword" value="' + esc(deviceState.keyword) + '"></div>'
        + '</div><div class="form-actions"><button class="btn btn-sm btn-primary" id="dv-search">筛选</button>'
        + '<button class="btn btn-sm btn-ghost" id="dv-reset">重置</button></div></div>';

      html += table(
        [{ text: '设备标识' }, { text: '平台' }, { text: '版本' }, { text: '累计敲击', num: true },
         { text: '启动', num: true }, { text: '最后活跃' }, { text: 'IP' }, { text: '状态' }, { text: '操作' }],
        (d.items || []).map(function (it) {
          return [
            { html: '<span class="mono-sm">' + esc(it.device_id) + '</span>' },
            it.platform,
            it.client_version,
            num(it.tap_total),
            num(it.launch_count),
            it.last_seen_at,
            it.last_ip_text || '—',
            { html: Number(it.status) === 1 ? '<span class="tag tag-jade">正常</span>' : '<span class="tag tag-rose">封禁</span>' },
            { html: '<div class="row-actions">'
              + '<button class="btn btn-sm" data-act="dev-toggle" data-id="' + it.id + '" data-status="' + it.status + '">'
              + (Number(it.status) === 1 ? '封禁' : '解封') + '</button>'
              + '<button class="btn btn-sm btn-ghost" data-act="dev-detail" data-id="' + it.id + '">详情</button></div>' }
          ];
        }), '没有匹配的设备');

      var pages = Math.max(1, Math.ceil(d.total / d.size));
      html += '<div class="pager"><span>第 ' + d.page + ' / ' + pages + ' 页</span>'
        + '<button class="btn btn-sm" id="dv-prev"' + (d.page <= 1 ? ' disabled' : '') + '>上一页</button>'
        + '<button class="btn btn-sm" id="dv-next"' + (d.page >= pages ? ' disabled' : '') + '>下一页</button></div>'
        + '<div id="dv-detail"></div>';

      $('#panel-devices').innerHTML = html;
      return d;
    });
  }

  function showDeviceDetail(id) {
    api('devices.detail', { id: id }, { silent: true }).then(function (d) {
      var dev = d.device, p = d.profile || {};
      var html = '<div class="admin-card" style="margin-top:14px"><h3>设备详情 · <span class="mono-sm">'
        + esc(dev.device_id) + '</span></h3>';
      var rows = [
        ['平台 / 系统', esc(dev.platform) + ' · ' + esc(dev.os_version || '—')],
        ['客户端版本', esc(dev.client_version || '—') + (dev.channel ? ' (' + esc(dev.channel) + ')' : '')],
        ['累计敲击', num(dev.tap_total) + '（快照 ' + num(dev.snapshot_tap_total) + '）'],
        ['累计功德', num(dev.merit_total)],
        ['启动 / 会话', num(dev.launch_count) + ' / ' + num(dev.session_count)],
        ['首次 / 最后', esc(dev.first_seen_at) + ' → ' + esc(dev.last_seen_at)],
        ['最近 IP', esc(dev.last_ip_text || '—')],
        ['今日 / 本周敲击', num(p.taps_today || 0) + ' / ' + num(p.taps_week || 0)],
        ['连续打卡', num(p.streak_days || 0) + ' 天'],
        ['称号', esc(p.title || '—') + '（Lv.' + num(p.level || 1) + '）'],
        ['功德榜', p.rank_opt_in ? ('已参与，名次 ' + (p.rank || '—')) : '未参与'],
        ['云同步设置', d.settings && d.settings.revision ? ('revision ' + d.settings.revision + '，' + esc(d.settings.updated_at)) : '无'],
        ['备注', esc(dev.note || '—')]
      ];
      rows.forEach(function (r) { html += '<div class="kv"><b>' + r[0] + '</b><span>' + r[1] + '</span></div>'; });
      html += '<div class="form-actions"><button class="btn btn-sm btn-ghost" id="dv-detail-close">收起</button></div></div>';
      $('#dv-detail').innerHTML = html;
      $('#dv-detail-close').addEventListener('click', function () { $('#dv-detail').innerHTML = ''; });
    });
  }

  /* ================= 版本发布 ================= */
  function renderReleases(editId) {
    return api('releases.list', {}, { silent: true }).then(function (d) {
      var html = '<h2 class="admin-h">版本发布 <span class="admin-sub">客户端「检查更新」直接读取这里的数据</span></h2>';
      html += table(
        [{ text: '平台' }, { text: '渠道' }, { text: '版本' }, { text: '构建' }, { text: '构建日期' },
         { text: '体积', num: true }, { text: '最低支持' }, { text: '强制' }, { text: '最新' }, { text: '操作' }],
        (d.items || []).map(function (r) {
          return [
            r.platform, r.channel, 'v' + r.version, r.build_number || '—', r.appbuild || '—',
            bytes(r.file_size), r.min_supported_version || '—',
            Number(r.force_upgrade) ? '<span class="tag tag-rose">是</span>' : '否',
            Number(r.is_latest) ? '<span class="tag tag-jade">是</span>' : '否',
            { html: '<div class="row-actions">'
              + '<button class="btn btn-sm" data-act="rel-edit" data-id="' + r.id + '">编辑</button>'
              + '<button class="btn btn-sm" data-act="rel-publish" data-id="' + r.id + '">设为最新</button>'
              + '<button class="btn btn-sm btn-ghost" data-act="rel-del" data-id="' + r.id + '">删除</button></div>' }
          ];
        }), '还没有发布记录');

      var cur = (d.items || []).filter(function (r) { return String(r.id) === String(editId); })[0] || {};
      html += '<h2 class="admin-h">' + (editId ? '编辑版本 #' + esc(editId) : '新增版本') + '</h2>';
      html += '<div class="admin-card"><div class="form-grid">'
        + field('platform', '平台', 'select', cur.platform || 'windows', OPTIONS.platforms)
        + field('channel', '渠道', 'select', cur.channel || 'release', OPTIONS.channels)
        + field('version', '版本号', 'text', cur.version || '', null, '3.1.0')
        + field('build_number', '构建号', 'text', cur.build_number || '', null, '310')
        + field('build_signature', '构建标识', 'text', cur.build_signature || '', null, '20261001')
        + field('appbuild', '构建日期', 'text', cur.appbuild || '', null, '2026-10-01')
        + field('installer_store', '分发渠道', 'text', cur.installer_store || '官网')
        + field('download_url', '下载地址', 'text', cur.download_url || '', null, 'https://…')
        + field('file_size', '文件体积（字节）', 'number', cur.file_size || '')
        + field('file_hash', '文件哈希', 'text', cur.file_hash || '', null, 'sha256:…', 'span2')
        + field('min_supported_version', '最低支持版本', 'text', cur.min_supported_version || '', null, '3.0.0')
        + field('published_at', '发布时间', 'text', cur.published_at || '', null, '2026-10-01 10:00:00')
        + '<div class="field span2"><label>更新说明</label><textarea id="f-newlog">' + esc(cur.newlog || '') + '</textarea></div>'
        + '</div><div class="form-actions">'
        + '<label class="check"><input type="checkbox" id="f-force"' + (Number(cur.force_upgrade) ? ' checked' : '') + '> 强制更新</label>'
        + '<label class="check"><input type="checkbox" id="f-sync" checked> 同时写入一条更新日志</label>'
        + '<button class="btn btn-primary" id="rel-save" data-id="' + esc(editId || '') + '">保存</button>'
        + (editId ? '<button class="btn btn-ghost" id="rel-cancel">取消编辑</button>' : '')
        + '</div></div>';

      $('#panel-releases').innerHTML = html;
      return d;
    });
  }

  /* ================= 更新日志 ================= */
  function renderChangelog(editId) {
    return api('changelog.list', {}, { silent: true }).then(function (d) {
      var html = '<h2 class="admin-h">更新日志 <span class="admin-sub">共 ' + num(d.total) + ' 条</span></h2>';
      html += table(
        [{ text: '日期' }, { text: '版本' }, { text: '平台' }, { text: '类型' }, { text: '标题' }, { text: '发布' }, { text: '操作' }],
        (d.items || []).map(function (c) {
          return [
            c.released_at, c.version ? 'v' + c.version : '—', c.platform, c.kind,
            { html: '<td class="wrap">' + esc(c.title) + '</td>' },
            Number(c.published) ? '<span class="tag tag-jade">已发布</span>' : '<span class="tag">草稿</span>',
            { html: '<div class="row-actions">'
              + '<button class="btn btn-sm" data-act="log-edit" data-id="' + c.id + '">编辑</button>'
              + '<button class="btn btn-sm btn-ghost" data-act="log-del" data-id="' + c.id + '">删除</button></div>' }
          ];
        }), '还没有更新日志');

      var cur = (d.items || []).filter(function (c) { return String(c.id) === String(editId); })[0] || {};
      html += '<h2 class="admin-h">' + (editId ? '编辑日志 #' + esc(editId) : '新增日志') + '</h2>';
      html += '<div class="admin-card"><div class="form-grid">'
        + field('version', '版本号', 'text', cur.version || '')
        + field('platform', '平台', 'select', cur.platform || 'all', ['all'].concat(OPTIONS.platforms))
        + field('channel', '渠道', 'select', cur.channel || 'release', OPTIONS.channels)
        + field('kind', '类型', 'select', cur.kind || 'feature', OPTIONS.kinds)
        + field('released_at', '日期', 'text', cur.released_at || new Date().toISOString().slice(0, 10))
        + field('sort_weight', '排序权重', 'number', cur.sort_weight || 0)
        + field('title', '标题', 'text', cur.title || '', null, '一句话说明这次更新', 'span2')
        + '<div class="field span2"><label>详细说明</label><textarea id="f-body">' + esc(cur.body || '') + '</textarea></div>'
        + '</div><div class="form-actions">'
        + '<label class="check"><input type="checkbox" id="f-published"' + (cur.id ? (Number(cur.published) ? ' checked' : '') : ' checked') + '> 已发布</label>'
        + '<button class="btn btn-primary" id="log-save" data-id="' + esc(editId || '') + '">保存</button>'
        + (editId ? '<button class="btn btn-ghost" id="log-cancel">取消编辑</button>' : '')
        + '</div></div>';

      $('#panel-changelog').innerHTML = html;
      return d;
    });
  }

  /* ================= 内容与配置 ================= */
  function renderContent() {
    return Promise.all([
      api('config.list', {}, { silent: true }),
      api('announcements.list', {}, { silent: true }),
      api('blessings.list', {}, { silent: true }),
      api('assets.list', {}, { silent: true })
    ]).then(function (res) {
      var cfg = res[0], ann = res[1], ble = res[2], ast = res[3];
      var html = '<h2 class="admin-h">运行时配置 <span class="admin-sub">客户端拉取后覆盖本地默认值，改完即生效（不发版）</span></h2>';
      html += table([{ text: '键' }, { text: '值' }, { text: '类型' }, { text: '平台' }, { text: '启用' }, { text: '说明' }, { text: '操作' }],
        (cfg.items || []).map(function (c) {
          return [c.config_key, { html: '<td class="wrap mono-sm">' + esc(c.config_value) + '</td>' }, c.value_type, c.platform,
            Number(c.status) ? '是' : '否', { html: '<td class="wrap">' + esc(c.description) + '</td>' },
            { html: '<button class="btn btn-sm btn-ghost" data-act="cfg-del" data-key="' + esc(c.config_key) + '">删除</button>' }];
        }), '暂无配置');
      html += '<div class="admin-card" style="margin-top:12px"><h3>新增 / 覆盖配置</h3><div class="form-grid">'
        + field('config_key', '键名', 'text', '', null, 'updateCheckIntervalH')
        + field('config_value', '值', 'text', '', null, '12')
        + field('value_type', '类型', 'select', 'string', ['string', 'int', 'float', 'bool', 'json'])
        + field('platform', '平台', 'select', 'all', ['all'].concat(OPTIONS.platforms))
        + field('description', '说明', 'text', '', null, '自动检查更新的间隔（小时）', 'span2')
        + '</div><div class="form-actions"><button class="btn btn-primary" id="cfg-save">保存配置</button></div></div>';

      html += '<h2 class="admin-h">公告</h2>';
      html += table([{ text: '标题' }, { text: '级别' }, { text: '平台' }, { text: '版本区间' }, { text: '时间窗' }, { text: '启用' }, { text: '操作' }],
        (ann.items || []).map(function (a) {
          return [a.title, a.level, a.platform,
            (a.min_version || '—') + ' ~ ' + (a.max_version || '—'),
            (a.start_at || '—') + ' → ' + (a.end_at || '—'),
            Number(a.status) ? '是' : '否',
            { html: '<div class="row-actions"><button class="btn btn-sm" data-act="ann-edit" data-id="' + a.id + '">编辑</button>'
              + '<button class="btn btn-sm btn-ghost" data-act="ann-del" data-id="' + a.id + '">删除</button></div>' }];
        }), '暂无公告');
      html += '<div class="admin-card" style="margin-top:12px"><h3>新增公告</h3><div class="form-grid">'
        + field('title', '标题', 'text', '', null, '维护通知')
        + field('level', '级别', 'select', 'info', ['info', 'notice', 'warn'])
        + field('platform', '平台', 'select', 'all', ['all'].concat(OPTIONS.platforms))
        + field('min_version', '最低版本', 'text', '', null, '可为空')
        + field('max_version', '最高版本', 'text', '', null, '可为空')
        + field('start_at', '开始时间', 'text', '', null, '2026-10-01 00:00:00')
        + field('end_at', '结束时间', 'text', '', null, '可为空')
        + '<div class="field span2"><label>内容</label><textarea id="f-content"></textarea></div>'
        + '</div><div class="form-actions"><button class="btn btn-primary" id="ann-save">发布公告</button></div></div>';

      html += '<h2 class="admin-h">功德语 / 每日一签 <span class="admin-sub">共 ' + num((ble.items || []).length) + ' 条</span></h2>';
      html += table([{ text: '分类' }, { text: '内容' }, { text: '出处' }, { text: '启用' }, { text: '操作' }],
        (ble.items || []).map(function (b) {
          return [b.category, { html: '<td class="wrap">' + esc(b.content) + '</td>' }, b.source || '—',
            Number(b.status) ? '是' : '否',
            { html: '<button class="btn btn-sm btn-ghost" data-act="ble-del" data-id="' + b.id + '">删除</button>' }];
        }), '暂无内容');
      html += '<div class="admin-card" style="margin-top:12px"><div class="form-grid">'
        + field('category', '分类', 'select', 'zen', ['zen', 'merit', 'humor'])
        + field('source', '出处', 'text', '', null, '内置')
        + '<div class="field span2"><label>内容</label><input type="text" id="f-ble-content" placeholder="一句话，最多 255 字"></div>'
        + '</div><div class="form-actions"><button class="btn btn-primary" id="ble-save">添加</button></div></div>';

      html += '<h2 class="admin-h">资源包（皮肤 / 音效）</h2>';
      html += table([{ text: '标识' }, { text: '名称' }, { text: '类型' }, { text: '平台' }, { text: '版本' }, { text: '大小' }, { text: '操作' }],
        (ast.items || []).map(function (a) {
          return [a.package_key, a.name, a.type, a.platform, a.version, bytes(a.file_size),
            { html: '<button class="btn btn-sm btn-ghost" data-act="ast-del" data-id="' + a.id + '">删除</button>' }];
        }), '暂无资源包');
      html += '<div class="admin-card" style="margin-top:12px"><div class="form-grid">'
        + field('package_key', '标识', 'text', '', null, 'skin-zen')
        + field('name', '名称', 'text', '', null, '禅意木鱼')
        + field('type', '类型', 'select', 'skin', ['skin', 'sound', 'font'])
        + field('platform', '平台', 'select', 'all', ['all'].concat(OPTIONS.platforms))
        + field('version', '版本', 'text', '1.0.0')
        + field('download_url', '下载地址', 'text', '', null, 'https://…', 'span2')
        + field('preview_url', '预览图', 'text', '', null, 'https://…')
        + field('file_hash', '哈希', 'text', '', null, 'sha256:…')
        + field('file_size', '体积（字节）', 'number', '')
        + field('description', '说明', 'text', '', null, '一句话介绍', 'span2')
        + '</div><div class="form-actions"><button class="btn btn-primary" id="ast-save">添加资源包</button></div></div>';

      $('#panel-content').innerHTML = html;
      return res;
    });
  }

  /* ================= 反馈与崩溃 ================= */
  function renderFeedback() {
    return Promise.all([
      api('feedback.list', {}, { silent: true }),
      api('crashes.list', {}, { silent: true })
    ]).then(function (res) {
      var fb = res[0], cr = res[1];
      var statusTag = { 0: '<span class="tag tag-amber">未读</span>', 1: '<span class="tag">已读</span>', 2: '<span class="tag tag-jade">已处理</span>' };
      var html = '<h2 class="admin-h">用户反馈 <span class="admin-sub">待处理 ' + num(fb.pending) + ' 条</span></h2>';
      html += table([{ text: '时间' }, { text: '分类' }, { text: '内容' }, { text: '联系方式' }, { text: '版本 / 平台' }, { text: '状态' }, { text: '操作' }],
        (fb.items || []).map(function (f) {
          return [f.created_at, f.category,
            { html: '<td class="wrap">' + esc((f.content || '').slice(0, 160)) + '</td>' },
            f.contact || '—',
            esc(f.client_version || '—') + ' / ' + esc(f.platform || '—'),
            { html: statusTag[f.status] || '' },
            { html: '<div class="row-actions">'
              + '<button class="btn btn-sm" data-act="fb-done" data-id="' + f.id + '">标记已处理</button>'
              + '<button class="btn btn-sm btn-ghost" data-act="fb-del" data-id="' + f.id + '">删除</button></div>' }];
        }), '暂无反馈');

      html += '<h2 class="admin-h">崩溃上报 <span class="admin-sub">共 ' + num(cr.total) + ' 条</span></h2>';
      html += table([{ text: '时间' }, { text: '类型' }, { text: '信息' }, { text: '版本' }, { text: '平台' }, { text: '次数', num: true }],
        (cr.items || []).map(function (c) {
          return [c.last_at, c.error_type, { html: '<td class="wrap">' + esc(c.message) + '</td>' },
            c.client_version || '—', c.platform || '—', num(c.occur_count)];
        }), '暂无崩溃上报');
      html += '<div class="form-actions"><button class="btn btn-ghost" data-act="crash-purge" data-days="30">清理 30 天前的崩溃上报</button></div>';

      $('#panel-feedback').innerHTML = html;
      return res;
    });
  }

  /* ================= 应用与令牌 ================= */
  function renderApps() {
    return Promise.all([
      api('apps.list', {}, { silent: true }),
      api('tokens.list', {}, { silent: true }),
      api('logins.list', {}, { silent: true })
    ]).then(function (res) {
      var apps = res[0], tokens = res[1], logins = res[2];
      var html = '<h2 class="admin-h">客户端应用 <span class="admin-sub">app_key 公开、app_secret 用于签名</span></h2>';
      html += table([{ text: 'ID' }, { text: 'app_key' }, { text: '密钥' }, { text: '名称' }, { text: '状态' },
        { text: '限流/分', num: true }, { text: '累计请求', num: true }, { text: '最后调用' }, { text: '操作' }],
        (apps.items || []).map(function (a) {
          return [a.id, { html: '<span class="mono-sm">' + esc(a.app_key) + '</span>' },
            { html: '<span class="mono-sm">' + esc(a.secret_masked) + '</span>' },
            a.name, Number(a.status) ? '<span class="tag tag-jade">启用</span>' : '<span class="tag tag-rose">停用</span>',
            num(a.rate_limit_per_min), num(a.request_total), a.last_used_at || '—',
            { html: '<button class="btn btn-sm" data-act="app-edit" data-id="' + a.id + '">编辑</button>' }];
        }), '暂无应用');

      var cur = apps.items && apps.items[0] ? apps.items[0] : {};
      html += '<h2 class="admin-h">编辑应用 #' + esc(cur.id || '') + '</h2>';
      html += '<div class="admin-card"><div class="form-grid">'
        + field('name', '名称', 'text', cur.name || '')
        + field('rate_limit_per_min', '每分钟限流', 'number', cur.rate_limit_per_min || 600)
        + field('note', '备注', 'text', cur.note || '', null, '内部说明')
        + '</div><div class="form-actions">'
        + '<label class="check"><input type="checkbox" id="f-app-status"' + (Number(cur.status) ? ' checked' : '') + '> 启用该客户端</label>'
        + '<label class="check"><input type="checkbox" id="f-rotate"> 轮换签名密钥（会使旧客户端上报失败）</label>'
        + '<label class="check"><input type="checkbox" id="f-confirm-rotate"> 我已确认要轮换</label>'
        + '<button class="btn btn-primary" id="app-save" data-id="' + esc(cur.id || '') + '">保存</button>'
        + '</div><div id="app-secret-out" class="result"></div></div>';

      html += '<h2 class="admin-h">访问令牌 <span class="admin-sub">供脚本 / CI 调用后台接口，令牌只显示一次</span></h2>';
      html += table([{ text: 'ID' }, { text: '标签' }, { text: '权限' }, { text: '过期' }, { text: '最后使用' }, { text: '操作' }],
        (tokens.items || []).map(function (t) {
          return [t.id, t.label, t.scope, t.expires_at || '永不过期', t.last_used_at || '—',
            { html: '<button class="btn btn-sm btn-ghost" data-act="token-del" data-id="' + t.id + '">删除</button>' }];
        }), '暂无令牌');
      html += '<div class="admin-card" style="margin-top:12px"><div class="form-grid">'
        + field('label', '标签', 'text', '', null, 'deploy-script')
        + field('scope', '权限', 'text', 'read,write')
        + field('ttl_days', '有效期（天，0=永久）', 'number', 30)
        + '</div><div class="form-actions"><button class="btn btn-primary" id="token-create">创建令牌</button></div>'
        + '<div id="token-out" class="result"></div></div>';

      html += '<h2 class="admin-h">最近登录</h2>';
      html += table([{ text: '时间' }, { text: 'IP' }, { text: '结果' }, { text: 'UA' }],
        (logins.items || []).map(function (l) {
          return [l.created_at, l.ip_text || '—', Number(l.success) ? '<span class="tag tag-jade">成功</span>' : '<span class="tag tag-rose">失败</span>',
            { html: '<td class="wrap mono-sm">' + esc((l.ua || '').slice(0, 90)) + '</td>' }];
        }), '暂无记录');

      $('#panel-apps').innerHTML = html;
      return res;
    });
  }

  /* ================= 审计与维护 ================= */
  function renderAudit() {
    return api('events.list', {}, { silent: true }).then(function (d) {
      var tasks = [
        ['purge_buckets', '清理限流 / nonce 桶', '删除已过期的限流计数与签名 nonce'],
        ['purge_online', '清理超时会话', '删除长时间无心跳的在线会话'],
        ['purge_events', '清理 60 天前事件', '精简 event_log'],
        ['purge_crash', '清理 30 天前崩溃', '精简 crash_reports'],
        ['vacuum_nonces', '清空过期 nonce', '立即释放 api_nonces 空间'],
        ['recalc_global', '重算全量统计', '用 daily_stats 重算 global_stats，用于数据核对']
      ];
      var html = '<h2 class="admin-h">维护工具 <span class="admin-sub">表体积异常或数据对不上时用</span></h2>';
      html += '<div class="admin-grid">' + tasks.map(function (t) {
        return '<div class="admin-card"><h3>' + esc(t[1]) + '</h3><p class="dim" style="font-size:13px">' + esc(t[2]) + '</p>'
          + '<div class="form-actions"><button class="btn btn-sm" data-act="maint" data-task="' + t[0] + '">执行</button></div></div>';
      }).join('') + '</div>';

      html += '<h2 class="admin-h">事件日志 <span class="admin-sub">共 ' + num(d.total) + ' 条</span></h2>';
      html += table([{ text: '时间' }, { text: '级别' }, { text: '事件' }, { text: '说明' }, { text: 'IP' }],
        (d.items || []).map(function (e) {
          return [e.created_at, e.level, e.event,
            { html: '<td class="wrap">' + esc(e.message) + '</td>' },
            e.ip ? '—' : '—'];
        }), '暂无事件');

      $('#panel-audit').innerHTML = html;
      return d;
    });
  }

  /* ---------- 表单字段小工具 ---------- */
  function field(id, label, type, value, optionsList, placeholder, extraClass) {
    var input;
    if (type === 'select') {
      input = '<select id="f-' + id + '">' + options(optionsList || [], value) + '</select>';
    } else {
      input = '<input type="' + (type === 'number' ? 'number' : 'text') + '" id="f-' + id + '" value="' + esc(value || '')
        + '"' + (placeholder ? ' placeholder="' + esc(placeholder) + '"' : '') + '>';
    }
    return '<div class="field ' + (extraClass || '') + '"><label for="f-' + id + '">' + esc(label) + '</label>' + input + '</div>';
  }

  function fv(id) {
    var el2 = $('#f-' + id);
    if (!el2) return '';
    return el2.value;
  }

  function fc(id) {
    var el2 = $('#f-' + id);
    return !!(el2 && el2.checked);
  }

  /* ================= 渲染调度 ================= */
  var renderers = {
    overview: renderOverview,
    devices: renderDevices,
    releases: renderReleases,
    changelog: renderChangelog,
    content: renderContent,
    feedback: renderFeedback,
    apps: renderApps,
    audit: renderAudit
  };
  var current = 'overview';

  function render(tab, arg) {
    var fn = renderers[tab];
    if (!fn) return Promise.resolve();
    var panel = $('#panel-' + tab);
    if (panel && !panel.innerHTML.trim()) {
      panel.innerHTML = '<div class="empty">正在加载…</div>';
    }
    return fn(arg).catch(function (e) {
      if (panel) panel.innerHTML = '<div class="empty">加载失败：' + esc(e.message) + '</div>';
    });
  }

  document.addEventListener('click', function (ev) {
    var tabBtn = ev.target.closest ? ev.target.closest('.tab') : null;
    if (tabBtn) {
      current = tabBtn.getAttribute('data-tab');
      $$('.tab').forEach(function (b) { b.classList.toggle('active', b === tabBtn); });
      $$('.panel').forEach(function (p) { p.classList.remove('active'); });
      var panel = $('#panel-' + current);
      if (panel) panel.classList.add('active');
      render(current);
      return;
    }

    var btn = ev.target.closest ? ev.target.closest('[data-act], #rel-save, #log-save, #cfg-save, #ann-save, #ble-save, #ast-save, #app-save, #token-create, #dv-search, #dv-reset, #dv-prev, #dv-next, #btn-logout, #rel-cancel, #log-cancel') : null;
    if (!btn) return;
    var act = btn.getAttribute('data-act') || btn.id;

    var handlers = {
      'dev-toggle': function () {
        var on = btn.getAttribute('data-status') === '1';
        var note = on ? (prompt('封禁原因（可留空）') || '') : '';
        if (on && note === null) return;
        api('devices.status', { id: btn.getAttribute('data-id'), status: !on, note: note }).then(reload);
      },
      'dev-detail': function () { showDeviceDetail(btn.getAttribute('data-id')); },
      'dv-search': function () {
        deviceState.platform = fv('dv-platform');
        deviceState.client_version = fv('dv-version');
        deviceState.status = fv('dv-status');
        deviceState.keyword = fv('dv-keyword');
        deviceState.page = 1;
        renderDevices();
      },
      'dv-reset': function () {
        deviceState = { page: 1, platform: '', client_version: '', status: '', keyword: '' };
        renderDevices();
      },
      'dv-prev': function () { deviceState.page = Math.max(1, deviceState.page - 1); renderDevices(); },
      'dv-next': function () { deviceState.page++; renderDevices(); },
      'rel-edit': function () { renderReleases(btn.getAttribute('data-id')); },
      'rel-publish': function () { api('releases.publish', { id: btn.getAttribute('data-id') }).then(reload); },
      'rel-del': function () { if (confirm('确定删除这条版本记录？')) api('releases.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'rel-save': function () {
        var payload = {
          id: btn.getAttribute('data-id') || 0,
          platform: fv('platform'), channel: fv('channel'), version: fv('version'),
          build_number: fv('build_number'), build_signature: fv('build_signature'),
          appbuild: fv('appbuild'), installer_store: fv('installer_store'),
          download_url: fv('download_url'), file_size: fv('file_size'), file_hash: fv('file_hash'),
          min_supported_version: fv('min_supported_version'), published_at: fv('published_at'),
          newlog: fv('newlog'), force_upgrade: fc('force'), sync_changelog: fc('sync')
        };
        api('releases.save', payload).then(function () { renderReleases(); });
      },
      'rel-cancel': function () { renderReleases(); },
      'log-edit': function () { renderChangelog(btn.getAttribute('data-id')); },
      'log-del': function () { if (confirm('确定删除这条日志？')) api('changelog.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'log-save': function () {
        api('changelog.save', {
          id: btn.getAttribute('data-id') || 0,
          version: fv('version'), platform: fv('platform'), channel: fv('channel'), kind: fv('kind'),
          released_at: fv('released_at'), sort_weight: fv('sort_weight'),
          title: fv('title'), body: fv('body'), published: fc('published')
        }).then(function () { renderChangelog(); });
      },
      'log-cancel': function () { renderChangelog(); },
      'cfg-save': function () {
        api('config.save', {
          config_key: fv('config_key'), config_value: fv('config_value'), value_type: fv('value_type'),
          platform: fv('platform'), description: fv('description'), status: true
        }).then(reload);
      },
      'cfg-del': function () { if (confirm('删除该配置？')) api('config.remove', { config_key: btn.getAttribute('data-key') }).then(reload); },
      'ann-save': function () {
        api('announcements.save', {
          title: fv('title'), level: fv('level'), platform: fv('platform'),
          min_version: fv('min_version'), max_version: fv('max_version'),
          start_at: fv('start_at'), end_at: fv('end_at'), content: fv('content'), status: true
        }).then(reload);
      },
      'ann-edit': function () { notify('公告编辑请直接用下方表单覆盖同名标题，或先删除再新增', false); },
      'ann-del': function () { if (confirm('删除该公告？')) api('announcements.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'ble-save': function () {
        api('blessings.save', { category: fv('category'), source: fv('source'), content: $('#f-ble-content').value, status: true }).then(reload);
      },
      'ble-del': function () { if (confirm('删除这条内容？')) api('blessings.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'ast-save': function () {
        api('assets.save', {
          package_key: fv('package_key'), name: fv('name'), type: fv('type'), platform: fv('platform'),
          version: fv('version'), download_url: fv('download_url'), preview_url: fv('preview_url'),
          file_hash: fv('file_hash'), file_size: fv('file_size'), description: fv('description'), status: true
        }).then(reload);
      },
      'ast-del': function () { if (confirm('删除该资源包？')) api('assets.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'fb-done': function () { api('feedback.mark', { id: btn.getAttribute('data-id'), status: 2 }).then(reload); },
      'fb-del': function () { if (confirm('删除该反馈？')) api('feedback.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'crash-purge': function () { api('crashes.purge', { days: btn.getAttribute('data-days') || 30 }).then(reload); },
      'app-save': function () {
        api('apps.save', {
          id: btn.getAttribute('data-id'), name: fv('name'), note: fv('note'),
          rate_limit_per_min: fv('rate_limit_per_min'), status: fc('app-status'),
          rotate_secret: fc('rotate'), confirm_rotate: fc('confirm-rotate')
        }).then(function (d) {
          if (d && d.app_secret) {
            $('#app-secret-out').className = 'result ok';
            $('#app-secret-out').textContent = '新密钥（只显示一次）：' + d.app_secret;
          }
          renderApps();
        });
      },
      'token-create': function () {
        api('tokens.create', { label: fv('label'), scope: fv('scope'), ttl_days: fv('ttl_days') }).then(function (d) {
          $('#token-out').className = 'result ok';
          $('#token-out').textContent = '令牌（只显示一次）：' + d.token;
          renderApps();
        });
      },
      'token-del': function () { if (confirm('删除该令牌？')) api('tokens.remove', { id: btn.getAttribute('data-id') }).then(reload); },
      'maint': function () {
        var task = btn.getAttribute('data-task');
        if (task === 'recalc_global' && !confirm('将用 daily_stats 重算全量统计，确定继续？')) return;
        api('maintenance', { task: task }).then(reload);
      },
      'btn-logout': function () { api('logout', {}, { silent: true }).then(function () { location.reload(); }); }
    };

    if (handlers[act]) {
      ev.preventDefault();
      handlers[act]();
    }
  });

  /* ---------- 启动 ---------- */
  function boot() {
    var clock = $('#clock');
    if (clock) {
      setInterval(function () {
        clock.textContent = new Date().toLocaleTimeString('zh-CN');
      }, 1000);
    }
    Promise.all([api('options', {}, { silent: true }), api('session', {}, { silent: true })])
      .then(function (res) {
        OPTIONS = res[0] || OPTIONS;
        render('overview');
        setInterval(function () {
          if (current === 'overview') renderOverview();
        }, 60000);
      })
      .catch(function (e) { notify('初始化失败：' + e.message, false); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
