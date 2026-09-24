<?php
/**
 * 可复用的页面组件：数字卡、柱状图、更新日志列表、状态标签。
 * 服务端渲染，保证首屏就有内容（不依赖 JS）。
 */
if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 数字统计卡。
 * $opts: live(bool 带呼吸点), key(data-live 键名), short(bool 用万/亿缩写), small(bool 小号字)
 */
function stat_card(string $label, $value, string $foot = '', array $opts = []): string
{
    $classes = ['stat'];
    if (!empty($opts['live'])) {
        $classes[] = 'live';
    }
    $attrs = '';
    if (!empty($opts['key'])) {
        $attrs .= ' data-live="' . e($opts['key']) . '"';
    }
    if (!empty($opts['short'])) {
        $attrs .= ' data-short';
    }
    $valueClass = !empty($opts['small']) ? 'value small' : 'value';
    $icon = !empty($opts['icon']) ? icon($opts['icon'], 14) : '';

    $html = '<div class="' . implode(' ', $classes) . '">';
    $html .= '<div class="label">' . $icon . e($label) . '</div>';
    $html .= '<div class="' . $valueClass . '"' . $attrs . '>' . e($value) . '</div>';
    if ($foot !== '') {
        $html .= '<div class="foot">' . e($foot) . '</div>';
    }
    return $html . '</div>';
}

/**
 * 柱状图（纯 CSS 高度，无 JS 图表库）。
 * 双序列：主序列（敲击）用翠色，次序列（启动/设备）用灰绿色。
 */
function render_bars(array $series, string $labelKey = 'date', string $primaryKey = 'taps', ?string $secondaryKey = null): string
{
    if (!$series) {
        return '<div class="chart-empty">暂无数据，敲一下木鱼试试。</div>';
    }
    $maxPrimary = 1;
    $maxSecondary = 1;
    foreach ($series as $row) {
        $maxPrimary = max($maxPrimary, (int) ($row[$primaryKey] ?? 0));
        if ($secondaryKey !== null) {
            $maxSecondary = max($maxSecondary, (int) ($row[$secondaryKey] ?? 0));
        }
    }

    $bars = '';
    $labels = '';
    foreach ($series as $row) {
        $p = (int) ($row[$primaryKey] ?? 0);
        $pHeight = max($p > 0 ? 4 : 2, (int) round($p / $maxPrimary * 100));
        $title = ($row[$labelKey] ?? '') . ' · 敲击 ' . num($p);
        $inner = '<div class="bar" style="height:' . $pHeight . '%" title="' . e($title) . '"></div>';
        if ($secondaryKey !== null) {
            $s = (int) ($row[$secondaryKey] ?? 0);
            $sHeight = max($s > 0 ? 4 : 2, (int) round($s / $maxSecondary * 100));
            $inner = '<div class="bar alt" style="height:' . $sHeight . '%" title="' . e(($row[$labelKey] ?? '') . ' · ' . $secondaryKey . ' ' . num($s)) . '"></div>' . $inner;
        }
        $bars .= '<div class="bar-col">' . $inner . '</div>';
        $labels .= '<span>' . e(date('m/d', strtotime((string) $row[$labelKey]))) . '</span>';
    }

    return '<div class="bars">' . $bars . '</div><div class="bar-x">' . $labels . '</div>';
}

/** 更新日志条目列表 */
function render_log_items(array $items, bool $timeline = true): string
{
    if (!$items) {
        return '<p class="muted">暂无更新日志。</p>';
    }
    $kindLabel = [
        'feature' => ['功能', 'tag-jade'],
        'fix' => ['修复', 'tag-amber'],
        'improve' => ['优化', 'tag'],
        'notice' => ['公告', 'tag'],
        'breaking' => ['破坏性变更', 'tag-rose'],
    ];
    $html = $timeline ? '<div class="timeline">' : '<div>';
    foreach ($items as $item) {
        list($label, $cls) = $kindLabel[$item['kind'] ?? 'feature'] ?? ['更新', 'tag'];
        $html .= '<article class="log-item">';
        $html .= '<div class="log-head">';
        if (!empty($item['version'])) {
            $html .= '<span class="ver">v' . e($item['version']) . '</span>';
        }
        $html .= '<span class="tag ' . $cls . '">' . e($label) . '</span>';
        if (!empty($item['platform']) && $item['platform'] !== 'all') {
            $html .= '<span class="tag">' . e(platform_label($item['platform'])) . '</span>';
        }
        $html .= '<span class="date">' . e(date('Y-m-d', strtotime((string) $item['released_at']))) . '</span>';
        $html .= '</div>';
        $html .= '<h3 class="log-title">' . e($item['title']) . '</h3>';
        if (!empty($item['body'])) {
            $html .= '<div class="log-body">' . e($item['body']) . '</div>';
        }
        $html .= '</article>';
    }
    return $html . '</div>';
}

/** 把字节数变成可读体积 */
function human_size($bytes): string
{
    $bytes = (float) $bytes;
    if ($bytes <= 0) {
        return '—';
    }
    $units = ['B', 'KB', 'MB', 'GB'];
    $i = 0;
    while ($bytes >= 1024 && $i < count($units) - 1) {
        $bytes /= 1024;
        $i++;
    }
    return round($bytes, $i === 0 ? 0 : 1) . ' ' . $units[$i];
}
