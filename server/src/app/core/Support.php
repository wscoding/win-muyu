<?php
/**
 * 无依赖的公共小工具：时间格式化、数字格式化、平台归一化、版本号比较、Markdown 渲染。
 *
 * 这里刻意不引入任何 composer 依赖 —— 服务器内存偏紧（可用约 0.9G），
 * 且 PHP 只有 7.4 一个版本，保持零依赖最省心。
 */
if (!defined('WID_APP')) {
    exit('forbidden');
}

/** HTML 转义（页面输出统一走它） */
function e($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** 千分位 */
function num($n): string
{
    return number_format((float) $n, 0, '.', ',');
}

/** 紧凑数字：1234 -> 1,234；1234567 -> 123.5万 */
function num_short($n): string
{
    $n = (float) $n;
    if ($n >= 100000000) {
        return rtrim(rtrim(number_format($n / 100000000, 2, '.', ''), '0'), '.') . '亿';
    }
    if ($n >= 10000) {
        return rtrim(rtrim(number_format($n / 10000, 1, '.', ''), '0'), '.') . '万';
    }
    return number_format($n, 0, '.', ',');
}

/** 时间友好化：刚刚 / 5 分钟前 / 3 小时前 / 09-21 */
function time_ago(?string $datetime): string
{
    if (!$datetime) {
        return '—';
    }
    $ts = strtotime($datetime);
    if ($ts === false) {
        return '—';
    }
    $diff = time() - $ts;
    if ($diff < 60) {
        return '刚刚';
    }
    if ($diff < 3600) {
        return intdiv($diff, 60) . ' 分钟前';
    }
    if ($diff < 86400) {
        return intdiv($diff, 3600) . ' 小时前';
    }
    if ($diff < 86400 * 30) {
        return date('m-d H:i', $ts);
    }
    return date('Y-m-d', $ts);
}

/** 平台名归一化，未知平台一律归入 other */
function platform_norm(?string $platform): string
{
    $p = strtolower(trim((string) $platform));
    $map = [
        'win' => 'windows', 'win32' => 'windows', 'windows' => 'windows', 'pc' => 'windows',
        'mac' => 'macos', 'macos' => 'macos', 'darwin' => 'macos', 'osx' => 'macos',
        'android' => 'android', 'harmony' => 'android', 'ohos' => 'android',
        'ios' => 'ios', 'iphone' => 'ios', 'ipados' => 'ios',
        'web' => 'web', 'linux' => 'linux',
    ];
    return $map[$p] ?? 'other';
}

/** 平台展示名 */
function platform_label(string $platform): string
{
    $map = [
        'windows' => 'Windows', 'macos' => 'macOS', 'android' => 'Android',
        'ios' => 'iOS', 'web' => 'Web', 'linux' => 'Linux', 'other' => '其他',
    ];
    return $map[$platform] ?? $platform;
}

/** 生成随机十六进制串（密钥、设备标识、nonce 用） */
function random_hex(int $bytes): string
{
    return bin2hex(random_bytes($bytes));
}

/**
 * 版本号比较。返回 -1 / 0 / 1。
 * 兼容 3.0.0 / 3.0 / v3.0.1 / 3.0.0-beta.2 这类写法。
 */
function version_compare_semver(string $a, string $b): int
{
    return Semver::compare($a, $b);
}

/**
 * 极简语义化版本号工具。
 */
final class Semver
{
    /** 拆分为 [主, 次, 修订, 预发布] */
    public static function parse(string $version): array
    {
        $v = strtolower(trim($version));
        $v = ltrim($v, 'v');
        $pre = '';
        if (strpos($v, '-') !== false) {
            list($v, $pre) = explode('-', $v, 2);
        }
        $parts = explode('.', $v);
        return [
            (int) ($parts[0] ?? 0),
            (int) ($parts[1] ?? 0),
            (int) ($parts[2] ?? 0),
            $pre,
        ];
    }

    public static function compare(string $a, string $b): int
    {
        $x = self::parse($a);
        $y = self::parse($b);
        for ($i = 0; $i < 3; $i++) {
            if ($x[$i] !== $y[$i]) {
                return $x[$i] < $y[$i] ? -1 : 1;
            }
        }
        // 有预发布号的版本小于同号正式版（1.0.0-beta < 1.0.0）
        if ($x[3] === $y[3]) {
            return 0;
        }
        if ($x[3] === '') {
            return 1;
        }
        if ($y[3] === '') {
            return -1;
        }
        return strcmp($x[3], $y[3]) < 0 ? -1 : 1;
    }

    /** 更新幅度：none / patch / minor / major */
    public static function diff_type(string $current, string $latest): string
    {
        $c = self::parse($current);
        $l = self::parse($latest);
        if ($l[0] > $c[0]) {
            return 'major';
        }
        if ($l[1] > $c[1]) {
            return 'minor';
        }
        if ($l[2] > $c[2]) {
            return 'patch';
        }
        return self::compare($current, $latest) < 0 ? 'patch' : 'none';
    }
}

/**
 * 极简 Markdown 渲染器（只覆盖文档用到的语法）。
 * 支持：标题 / 段落 / 围栏代码 / 行内代码 / 表格 / 无序列表 / 有序列表 /
 *       引用 / 分隔线 / 粗体 / 链接。故意不追求完整 CommonMark。
 */
final class Markdown
{
    /** 标题序号计数器：render() 与 toc() 用同一套规则，保证锚点能对上 */
    private static $headingSeq = 0;

    /**
     * 提取目录（只取 ## 与 ###）。
     * 返回 [['level'=>2,'text'=>'…','anchor'=>'sec-1'], ...]
     */
    public static function toc(string $md): array
    {
        $out = [];
        $seq = 0;
        foreach (preg_split('/\r\n|\r|\n/', $md) as $line) {
            if (preg_match('/^(#{2,3})\s+(.*)$/', $line, $m)) {
                $seq++;
                $out[] = [
                    'level'  => strlen($m[1]),
                    'text'   => trim($m[2]),
                    'anchor' => 'sec-' . $seq,
                ];
            }
        }
        return $out;
    }

    public static function render(string $md): string
    {
        self::$headingSeq = 0;
        $lines = preg_split('/\r\n|\r|\n/', $md);
        $out = [];
        $i = 0;
        $n = count($lines);

        while ($i < $n) {
            $line = $lines[$i];

            // 围栏代码块
            if (preg_match('/^\s*```(\w*)\s*$/', $line, $m)) {
                $lang = $m[1];
                $code = [];
                $i++;
                while ($i < $n && !preg_match('/^\s*```\s*$/', $lines[$i])) {
                    $code[] = $lines[$i];
                    $i++;
                }
                $i++; // 跳过结束围栏
                $cls = $lang !== '' ? ' class="lang-' . e($lang) . '"' : '';
                $out[] = '<pre class="code"><code' . $cls . '>' . e(implode("\n", $code)) . '</code></pre>';
                continue;
            }

            // 分隔线
            if (preg_match('/^\s*([-*_])\1{2,}\s*$/', $line)) {
                $out[] = '<hr>';
                $i++;
                continue;
            }

            // 标题
            if (preg_match('/^(#{1,6})\s+(.*)$/', $line, $m)) {
                $level = strlen($m[1]);
                $idAttr = '';
                if ($level >= 2 && $level <= 3) {
                    self::$headingSeq++;
                    $idAttr = ' id="sec-' . self::$headingSeq . '"';
                }
                $out[] = '<h' . $level . $idAttr . '>' . self::inline(trim($m[2])) . '</h' . $level . '>';
                $i++;
                continue;
            }

            // 表格
            if (strpos($line, '|') !== false && $i + 1 < $n
                && preg_match('/^\s*\|?[\s:|-]+\|[\s:|-]*$/', $lines[$i + 1])) {
                $head = self::cells($line);
                $i += 2;
                $rows = [];
                while ($i < $n && strpos($lines[$i], '|') !== false && trim($lines[$i]) !== '') {
                    $rows[] = self::cells($lines[$i]);
                    $i++;
                }
                $html = '<div class="table-wrap"><table><thead><tr>';
                foreach ($head as $c) {
                    $html .= '<th>' . self::inline($c) . '</th>';
                }
                $html .= '</tr></thead><tbody>';
                foreach ($rows as $row) {
                    $html .= '<tr>';
                    for ($k = 0; $k < count($head); $k++) {
                        $html .= '<td>' . self::inline($row[$k] ?? '') . '</td>';
                    }
                    $html .= '</tr>';
                }
                $out[] = $html . '</tbody></table></div>';
                continue;
            }

            // 引用
            if (preg_match('/^\s*>\s?(.*)$/', $line, $m)) {
                $buf = [];
                while ($i < $n && preg_match('/^\s*>\s?(.*)$/', $lines[$i], $mm)) {
                    $buf[] = $mm[1];
                    $i++;
                }
                $out[] = '<blockquote>' . self::inline(implode(' ', $buf)) . '</blockquote>';
                continue;
            }

            // 列表
            if (preg_match('/^\s*([-*+]|\d+\.)\s+(.*)$/', $line, $m)) {
                $ordered = preg_match('/^\d+\.$/', $m[1]) === 1;
                $items = [];
                while ($i < $n && preg_match('/^\s*([-*+]|\d+\.)\s+(.*)$/', $lines[$i], $mm)) {
                    $items[] = $mm[2];
                    $i++;
                }
                $tag = $ordered ? 'ol' : 'ul';
                $html = '<' . $tag . '>';
                foreach ($items as $it) {
                    $html .= '<li>' . self::inline($it) . '</li>';
                }
                $out[] = $html . '</' . $tag . '>';
                continue;
            }

            // 空行
            if (trim($line) === '') {
                $i++;
                continue;
            }

            // 段落（连续非空行合并）
            $buf = [];
            while ($i < $n && trim($lines[$i]) !== ''
                && !preg_match('/^\s*(#{1,6}\s|```|>|[-*+]\s|\d+\.\s)/', $lines[$i])
                && strpos($lines[$i], '|') === false) {
                $buf[] = trim($lines[$i]);
                $i++;
            }
            if ($buf) {
                $out[] = '<p>' . self::inline(implode(' ', $buf)) . '</p>';
            } else {
                $i++;
            }
        }

        return implode("\n", $out);
    }

    private static function cells(string $line): array
    {
        $line = trim($line);
        $line = trim($line, '|');
        return array_map('trim', explode('|', $line));
    }

    /** 行内元素：`code` / **粗体** / [文本](链接) */
    private static function inline(string $text): string
    {
        $escaped = e($text);
        $escaped = preg_replace('/`([^`]+)`/', '<code>$1</code>', $escaped);
        $escaped = preg_replace('/\*\*([^*]+)\*\*/', '<strong>$1</strong>', $escaped);
        $escaped = preg_replace_callback(
            '/\[([^\]]+)\]\(([^)\s]+)\)/',
            static function ($m) {
                return '<a href="' . $m[2] . '" rel="noopener">' . $m[1] . '</a>';
            },
            $escaped
        );
        return $escaped;
    }
}
