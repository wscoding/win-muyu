/* ============================================================
   wid.chr.cc 站点脚本
   只做三件事：实时数字刷新、更新检测表单、代码块复制。
   刻意不引入任何框架 —— 页面主体是服务端渲染的，断网也能正常阅读。
   ============================================================ */
(function () {
  'use strict';

  var API = '/api/v1';

  function qs(sel, root) { return (root || document).querySelector(sel); }
  function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function fmt(n) {
    n = Number(n) || 0;
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  function fmtShort(n) {
    n = Number(n) || 0;
    if (n >= 100000000) return (n / 100000000).toFixed(2).replace(/\.?0+$/, '') + '亿';
    if (n >= 10000) return (n / 10000).toFixed(1).replace(/\.?0+$/, '') + '万';
    return fmt(n);
  }

  function setText(el, text) {
    if (!el) return;
    if (el.textContent === text) return;
    el.textContent = text;
    el.animate(
      [{ opacity: .35, transform: 'translateY(-3px)' }, { opacity: 1, transform: 'none' }],
      { duration: 420, easing: 'cubic-bezier(.2,.8,.3,1)' }
    );
  }

  /* ---------- 实时数字 ---------- */
  function applyStats(data) {
    qsa('[data-live]').forEach(function (el) {
      var key = el.getAttribute('data-live');
      var short = el.hasAttribute('data-short');
      var value;
      switch (key) {
        case 'taps': value = data.taps; break;
        case 'merit': value = data.merit; break;
        case 'launches': value = data.launches; break;
        case 'online': value = data.online; break;
        case 'devices': value = data.devices; break;
        case 'peak': value = data.online_peak; break;
        case 'today_taps': value = data.today && data.today.taps; break;
        case 'today_launches': value = data.today && data.today.launches; break;
        case 'today_devices': value = data.today && data.today.devices; break;
        default: return;
      }
      setText(el, short ? fmtShort(value) : fmt(value));
    });
  }

  /* ---------- 整页区块重绘 ---------- */
  //
  // 数字卡之外的区块（趋势图、明细表、分布、榜单）原来只在服务端渲染一次，
  // 敲完木鱼必须手动刷新页面才能看到。这里按 overview 接口返回的 JSON
  // 重新生成同样的 DOM，让整页都跟着动。
  // 所有插入的文本都先 esc()，避免后台录入的昵称把页面搞坏。

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function mmdd(date) {
    var p = String(date || '').split('-');
    return p.length >= 3 ? p[1] + '/' + p[2] : String(date || '');
  }

  function renderBars(el, series) {
    if (!el) return;
    var target = el.querySelector('.bars-wrap') || el;
    // 只替换图表本体，保留标题与图例
    ['bars', 'bar-x', 'chart-empty'].forEach(function (cls) {
      var node = el.querySelector('.' + cls);
      if (node) node.remove();
    });
    if (!series || !series.length) {
      var empty = document.createElement('div');
      empty.className = 'chart-empty';
      empty.textContent = '暂无数据，敲一下木鱼试试。';
      target.appendChild(empty);
      return;
    }
    var maxP = 1, maxS = 1;
    series.forEach(function (r) {
      maxP = Math.max(maxP, Number(r.taps) || 0);
      maxS = Math.max(maxS, Number(r.devices) || 0);
    });
    var bars = '', labels = '';
    series.forEach(function (r) {
      var p = Number(r.taps) || 0;
      var s = Number(r.devices) || 0;
      var ph = Math.max(p > 0 ? 4 : 2, Math.round(p / maxP * 100));
      var sh = Math.max(s > 0 ? 4 : 2, Math.round(s / maxS * 100));
      bars += '<div class="bar-col">'
        + '<div class="bar alt" style="height:' + sh + '%" title="' + esc(mmdd(r.date) + ' · 设备 ' + fmt(s)) + '"></div>'
        + '<div class="bar" style="height:' + ph + '%" title="' + esc(r.date + ' · 敲击 ' + fmt(p)) + '"></div>'
        + '</div>';
      labels += '<span>' + esc(mmdd(r.date)) + '</span>';
    });
    target.insertAdjacentHTML('beforeend', '<div class="bars">' + bars + '</div><div class="bar-x">' + labels + '</div>');
  }

  function renderTrend7(el, series) {
    if (!el || !series) return;
    var rows = series.slice(-7).reverse();
    el.innerHTML = rows.map(function (r) {
      return '<tr><td>' + esc(r.date) + '</td>'
        + '<td class="num">' + esc(fmt(r.taps)) + '</td>'
        + '<td class="num">' + esc(fmt(r.launches)) + '</td>'
        + '<td class="num">' + esc(fmt(r.devices)) + '</td></tr>';
    }).join('') || '<tr><td colspan="4" class="dim">暂无数据</td></tr>';
  }

  function renderPlatforms(el, list) {
    if (!el) return;
    if (!list || !list.length) { el.innerHTML = '<tr><td colspan="3" class="dim">暂无数据</td></tr>'; return; }
    el.innerHTML = list.map(function (r) {
      return '<tr><td>' + esc(r.label || r.platform) + '</td>'
        + '<td class="num">' + esc(fmt(r.devices)) + '</td>'
        + '<td class="num">' + esc(fmt(r.online)) + '</td></tr>';
    }).join('');
  }

  function renderVersions(el, list) {
    if (!el) return;
    if (!list || !list.length) { el.innerHTML = '<tr><td colspan="2" class="dim">暂无数据</td></tr>'; return; }
    el.innerHTML = list.map(function (r) {
      return '<tr><td class="mono">v' + esc(r.version || '未知') + '</td>'
        + '<td class="num">' + esc(fmt(r.devices)) + '</td></tr>';
    }).join('');
  }

  function renderBoard(el, items) {
    if (!el) return;
    if (!items || !items.length) {
      el.innerHTML = '<tr><td colspan="4" class="dim">'
        + '还没有人开启功德榜。在客户端「设置 → 功德榜」里开启即可上榜。</td></tr>';
      return;
    }
    el.innerHTML = items.map(function (r) {
      return '<tr><td class="num" style="width:64px">' + esc(r.rank) + '</td>'
        + '<td>' + esc(r.nickname) + '</td>'
        + '<td class="dim">' + esc(r.platform_label || r.platform) + '</td>'
        + '<td class="num">' + esc(fmt(r.taps)) + '</td></tr>';
    }).join('');
  }

  function applyBlocks(data) {
    if (!data) return;
    renderBars(qs('[data-live-block="trend30"]'), data.trend);
    renderTrend7(qs('[data-live-block="trend7"]'), data.trend);
    if (data.breakdown) {
      renderPlatforms(qs('[data-live-block="platforms"]'), data.breakdown.platforms);
      renderVersions(qs('[data-live-block="versions"]'), data.breakdown.versions);
    }
    if (data.leaderboard) renderBoard(qs('[data-live-block="board"]'), data.leaderboard.items);
  }

  /* ---------- 刷新调度 ---------- */
  var REFRESH_MS = 30000;
  var paused = false;
  var timer = null;
  var lastTaps = null;

  function setUpdated(text) {
    qsa('[data-live-updated]').forEach(function (el) { el.textContent = text; });
  }

  function pulse(delta) {
    // 有新敲击时给个可见反馈，否则"刷新了但没变化"跟"根本没刷新"看起来一样
    var dot = qs('.live-dot');
    if (!dot) return;
    dot.classList.add('ping');
    setTimeout(function () { dot.classList.remove('ping'); }, 1200);
    if (delta > 0) {
      qs('.live-text') && (qs('.live-text').setAttribute('title', '本次刷新新增 ' + fmt(delta) + ' 次敲击'));
    }
  }

  function refreshStats() {
    if (!document.querySelector('[data-live]')) return;
    fetch(API + '/stats/overview?days=30&range=week&limit=10',
      { headers: { 'Accept': 'application/json' }, cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (!res || !res.ok || !res.data) return;
        applyStats(res.data.summary);
        applyBlocks(res.data);
        var taps = res.data.summary && res.data.summary.taps;
        if (lastTaps !== null && typeof taps === 'number' && taps > lastTaps) pulse(taps - lastTaps);
        lastTaps = typeof taps === 'number' ? taps : lastTaps;
        setUpdated(new Date().toTimeString().slice(0, 8));
      })
      .catch(function () { /* 静默：刷新失败不影响已渲染的服务端数据 */ });
  }

  function startTimer() {
    stopTimer();
    timer = setInterval(refreshStats, REFRESH_MS);
  }
  function stopTimer() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  function initDashboardControls() {
    var btnRefresh = qs('#dash-refresh');
    var btnToggle = qs('#dash-toggle');
    if (btnRefresh) btnRefresh.addEventListener('click', function () { refreshStats(); });
    if (btnToggle) {
      btnToggle.addEventListener('click', function () {
        paused = !paused;
        btnToggle.textContent = paused ? '继续' : '暂停';
        btnToggle.setAttribute('aria-pressed', paused ? 'true' : 'false');
        if (paused) stopTimer(); else startTimer();
      });
    }
  }

  /* ---------- 更新检测 ---------- */
  function detectPlatform() {
    var ua = navigator.userAgent;
    if (/Mac OS X|Macintosh/.test(ua)) return 'macos';
    if (/Android/.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
    if (/Windows|Win32|Win64/.test(ua)) return 'windows';
    return 'windows';
  }

  function initUpdateChecker() {
    var form = qs('#update-form');
    if (!form) return;
    var out = qs('#update-result');
    var platformSel = qs('#up-platform');
    var channelSel = qs('#up-channel');
    var currentInput = qs('#up-current');

    if (platformSel && !platformSel.value) platformSel.value = detectPlatform();

    form.addEventListener('submit', function (ev) {
      ev.preventDefault();
      var platform = platformSel ? platformSel.value : 'windows';
      var channel = channelSel ? channelSel.value : 'release';
      var current = currentInput ? currentInput.value.trim() : '';
      out.className = 'result';
      out.textContent = '正在检查…';

      var url = API + '/version?platform=' + encodeURIComponent(platform)
        + '&channel=' + encodeURIComponent(channel)
        + (current ? '&current=' + encodeURIComponent(current) : '');

      fetch(url, { headers: { 'Accept': 'application/json' } })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          if (!res.ok) { out.className = 'result err'; out.textContent = res.msg || '检查失败'; return; }
          var d = res.data;
          if (!d.latest) {
            out.className = 'result warn';
            out.textContent = '该平台 / 渠道还没有发布记录。';
            return;
          }
          var html = '';
          if (d.has_update) {
            html = '<span class="tag tag-jade">发现新版本</span> 最新版本 <strong>v' + d.latest.version + '</strong>'
              + '（当前 ' + (d.current || '未知') + '，' + d.update_type + '）'
              + (d.force_upgrade ? ' <span class="tag tag-rose">强制更新</span>' : '');
            if (d.latest.download_url) {
              html += ' · <a href="' + d.latest.download_url + '">立即下载</a>';
            }
            out.className = 'result ok';
          } else {
            html = '<span class="tag tag-jade">已是最新</span> 当前 v' + (d.current || d.latest.version)
              + '，服务端最新 v' + d.latest.version + '。';
            out.className = 'result ok';
          }
          out.innerHTML = html;
        })
        .catch(function (e) {
          out.className = 'result err';
          out.textContent = '请求失败：' + e.message;
        });
    });
  }

  /* ---------- 代码块复制 ---------- */
  function initCopy() {
    qsa('pre.code').forEach(function (pre) {
      var btn = document.createElement('button');
      btn.className = 'btn btn-sm';
      btn.type = 'button';
      btn.textContent = '复制';
      btn.style.cssText = 'position:absolute;right:10px;top:10px;opacity:.75;padding:4px 10px;font-size:12px';
      pre.style.position = 'relative';
      btn.addEventListener('click', function () {
        var text = pre.querySelector('code') ? pre.querySelector('code').textContent : pre.textContent;
        navigator.clipboard.writeText(text).then(function () {
          btn.textContent = '已复制';
          setTimeout(function () { btn.textContent = '复制'; }, 1400);
        }).catch(function () { btn.textContent = '复制失败'; });
      });
      pre.appendChild(btn);
    });
  }

  /* ---------- 每日一签 ---------- */
  function initBlessing() {
    var box = qs('#blessing-box');
    if (!box) return;
    fetch(API + '/blessing', { headers: { 'Accept': 'application/json' } })
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (!res.ok || !res.data) return;
        setText(qs('#blessing-text', box), res.data.content);
        var src = qs('#blessing-source', box);
        if (src) src.textContent = res.data.source ? '— ' + res.data.source : '';
      })
      .catch(function () {});
  }

  function boot() {
    initDashboardControls();
    refreshStats();
    initUpdateChecker();
    initCopy();
    initBlessing();
    if (document.querySelector('[data-live]')) {
      startTimer();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
