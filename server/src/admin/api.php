<?php
/**
 * 管理后台接口。
 *
 * 约定：全部以 POST + JSON（或表单）调用，除 `login` 外都必须登录，
 * 除只读动作外都必须带 `X-CSRF` 头。
 * 所有写操作都会写一条 event_log，便于事后追溯"谁在什么时候改了什么"。
 */
require_once dirname(__DIR__) . '/app/bootstrap.php';
require_once __DIR__ . '/lib/AdminAuth.php';

use Wid\Admin\AdminAuth;
use Wid\Core\Db;
use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Rate;
use Wid\Core\Respond;
use Wid\Model\AppKey;
use Wid\Model\Changelog;
use Wid\Model\Content;
use Wid\Model\Device;
use Wid\Model\Feedback;
use Wid\Model\Online;
use Wid\Model\Release;
use Wid\Model\Settings;
use Wid\Model\Stats;

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');

$action = (string) Http::input('action', '');

/** 只读动作白名单，其余一律要求 CSRF */
$readOnly = [
    'session', 'overview', 'stats.trend', 'devices.list', 'devices.detail',
    'releases.list', 'changelog.list', 'apps.list', 'config.list', 'announcements.list',
    'blessings.list', 'assets.list', 'feedback.list', 'crashes.list', 'events.list',
    'tokens.list', 'logins.list', 'options',
];

try {
    // ---------- 免登录 ----------
    if ($action === 'login') {
        $result = AdminAuth::login((string) Http::input('password', ''));
        if (!$result['ok']) {
            Respond::json(['csrf' => AdminAuth::csrfToken()], 40302, $result['msg'], 401, 0, false);
        }
        Respond::ok(['csrf' => $result['csrf']], $result['msg']);
    }
    if ($action === 'logout') {
        AdminAuth::logout();
        Respond::ok(null, '已退出登录');
    }

    // ---------- 鉴权 ----------
    if (in_array($action, $readOnly, true)) {
        $actor = AdminAuth::requireLoginJson();
    } else {
        $actor = AdminAuth::requireWrite();
    }
    $who = (string) ($actor['actor'] ?? 'admin');

    switch ($action) {
        // ================= 概览 =================
        case 'session':
            $app = AppKey::find(AppKey::defaultId());
            if ($app) {
                unset($app['app_secret']);
            }
            Respond::ok([
                'csrf'       => AdminAuth::csrfToken(),
                'actor'      => $who,
                'server_time' => date('c'),
                'app'        => $app ?: null,
            ]);
            break;

        case 'overview':
            $summary = Stats::summary();
            $appId = AppKey::defaultId();
            Respond::ok([
                'summary'    => $summary,
                'trend'      => Stats::trend(14),
                'platforms'  => Device::platformBreakdown(),
                'versions'   => Device::versionBreakdown(8),
                'online_by_platform' => Online::countByPlatform(),
                'pending_feedback'   => Feedback::pendingCount(),
                'crashes'    => Feedback::crashCount(),
                'releases'   => Release::latestAll($appId),
                'latest_events' => Event::recent(8),
            ]);
            break;

        case 'options':
            Respond::ok([
                'versions'  => Device::knownVersions(),
                'platforms' => Release::PLATFORMS,
                'channels'  => Release::CHANNELS,
                'kinds'     => Changelog::KINDS,
                'feedback_categories' => Feedback::CATEGORIES,
            ]);
            break;

        // ================= 设备 =================
        case 'devices.list':
            $page = max(1, Http::int('page', 1));
            $size = min(100, max(5, Http::int('size', 30)));
            $filter = [
                'platform'       => Http::str('platform', '', 16),
                'client_version' => Http::str('client_version', '', 24),
                'status'         => Http::input('status', ''),
                'keyword'        => Http::str('keyword', '', 64),
            ];
            Respond::ok([
                'total' => Device::countFiltered($filter),
                'page'  => $page,
                'size'  => $size,
                'items' => Device::paginate($filter, $page, $size),
            ]);
            break;

        case 'devices.detail':
            $pk = Http::int('id', 0);
            $device = Device::findByPk($pk);
            if (!$device) {
                Respond::json(null, 40001, '设备不存在', 404, 0, false);
            }
            $device['last_ip_text'] = Http::ipText($device['last_ip']);
            unset($device['last_ip']);
            Respond::ok([
                'device'   => $device,
                'profile'  => \Wid\Model\Rank::profile($pk),
                'settings' => Settings::pull($pk),
            ]);
            break;

        case 'devices.status':
            $pk = Http::int('id', 0);
            $status = Http::bool('status', true) ? 1 : 0;
            $note = Http::str('note', '', 120);
            Device::setStatus($pk, $status, $note);
            if (!$status) {
                Online::forget($pk);
            }
            Event::log('device_status', '设备 #' . $pk . ' 状态改为 ' . ($status ? '正常' : '封禁') . ' ' . $note, 'warn', null, $who);
            Respond::ok(['id' => $pk, 'status' => $status], $status ? '已恢复正常' : '已封禁');
            break;

        // ================= 版本发布 =================
        case 'releases.list':
            Respond::ok(['items' => Release::all(Http::str('platform', '', 16) ?: null, 200)]);
            break;

        case 'releases.save':
            $id = Http::int('id', 0) ?: null;
            $appId = AppKey::defaultId();
            $saved = Release::save($appId, [
                'platform' => Http::str('platform', 'windows', 16),
                'channel' => Http::str('channel', 'release', 16),
                'version' => Http::str('version', '', 24),
                'build_number' => Http::str('build_number', '', 24),
                'build_signature' => Http::str('build_signature', '', 64),
                'appbuild' => Http::str('appbuild', '', 24),
                'installer_store' => Http::str('installer_store', '', 64),
                'newlog' => Http::str('newlog', '', 4000),
                'download_url' => Http::str('download_url', '', 255),
                'file_size' => Http::input('file_size', ''),
                'file_hash' => Http::str('file_hash', '', 128),
                'min_supported_version' => Http::str('min_supported_version', '', 24),
                'force_upgrade' => Http::bool('force_upgrade', false),
                'published_at' => Http::str('published_at', '', 32),
            ], $id);
            // 顺带把 newlog 记为一条更新日志，避免两处手工维护
            $newlog = Http::str('newlog', '', 4000);
            if ($newlog !== '' && Http::bool('sync_changelog', false)) {
                Changelog::save($appId, [
                    'version' => Http::str('version', '', 24),
                    'platform' => Http::str('platform', 'all', 16),
                    'channel' => Http::str('channel', 'release', 16),
                    'kind' => 'feature',
                    'title' => 'v' . Http::str('version', '', 24) . ' 发布',
                    'body' => $newlog,
                    'released_at' => Http::str('appbuild', date('Y-m-d'), 24) ?: date('Y-m-d'),
                    'published' => 1,
                ]);
            }
            Event::log('release_save', '保存版本记录 #' . $saved, 'info', $appId, $who);
            Respond::ok(['id' => $saved], '版本记录已保存');
            break;

        case 'releases.publish':
            $id = Http::int('id', 0);
            Release::publish($id);
            Event::log('release_publish', '发布版本 #' . $id, 'info', null, $who);
            Respond::ok(['id' => $id], '已设为该平台 / 渠道的最新版');
            break;

        case 'releases.remove':
            $id = Http::int('id', 0);
            Release::remove($id);
            Event::log('release_remove', '删除版本记录 #' . $id, 'warn', null, $who);
            Respond::ok(['id' => $id], '已删除');
            break;

        // ================= 更新日志 =================
        case 'changelog.list':
            Respond::ok(['items' => Changelog::all(100, Http::int('offset', 0)), 'total' => Changelog::count()]);
            break;

        case 'changelog.save':
            $id = Http::int('id', 0) ?: null;
            $saved = Changelog::save(AppKey::defaultId(), [
                'version' => Http::str('version', '', 24),
                'platform' => Http::str('platform', 'all', 16),
                'channel' => Http::str('channel', 'release', 16),
                'kind' => Http::str('kind', 'feature', 12),
                'title' => Http::str('title', '', 128),
                'body' => Http::str('body', '', 4000),
                'released_at' => Http::str('released_at', date('Y-m-d'), 24),
                'published' => Http::bool('published', true),
                'sort_weight' => Http::int('sort_weight', 0),
            ], $id);
            Event::log('changelog_save', '保存更新日志 #' . $saved, 'info', null, $who);
            Respond::ok(['id' => $saved], '已保存');
            break;

        case 'changelog.remove':
            $id = Http::int('id', 0);
            Changelog::remove($id);
            Event::log('changelog_remove', '删除更新日志 #' . $id, 'warn', null, $who);
            Respond::ok(['id' => $id], '已删除');
            break;

        // ================= 应用密钥 =================
        case 'apps.list':
            $apps = AppKey::all();
            foreach ($apps as &$app) {
                $app['secret_masked'] = strlen((string) $app['app_secret']) > 8
                    ? substr((string) $app['app_secret'], 0, 6) . '…' . substr((string) $app['app_secret'], -4)
                    : '****';
                unset($app['app_secret']);
            }
            Respond::ok(['items' => $apps]);
            break;

        case 'apps.save':
            $id = Http::int('id', 0);
            $fields = [
                'name' => Http::str('name', '', 64),
                'status' => Http::bool('status', true) ? 1 : 0,
                'rate_limit_per_min' => max(30, min(100000, Http::int('rate_limit_per_min', 600))),
                'note' => Http::str('note', '', 120),
            ];
            if (Http::bool('rotate_secret', false)) {
                // 轮换密钥会让所有旧客户端签名失效，必须显式二次确认
                if (!Http::bool('confirm_rotate', false)) {
                    Respond::json(null, 40001, '轮换密钥会使所有旧客户端上报失败，请勾选确认', 400, 0, false);
                }
                $fields['app_secret'] = random_hex(32);
            }
            AppKey::update($id, $fields);
            Event::log('app_save', '更新应用 #' . $id . (!empty($fields['app_secret']) ? '（已轮换密钥）' : ''), 'warn', $id, $who);
            $result = ['id' => $id];
            if (!empty($fields['app_secret'])) {
                $result['app_secret'] = $fields['app_secret'];
                $result['notice'] = '请立即把新密钥写入客户端；刷新后不再显示。';
            }
            Respond::ok($result, '已保存');
            break;

        // ================= 运行时配置 =================
        case 'config.list':
            Respond::ok(['items' => Content::configList()]);
            break;

        case 'config.save':
            Content::saveConfig(
                Http::str('config_key', '', 48),
                Http::input('config_value', ''),
                Http::str('value_type', 'string', 12),
                Http::str('platform', 'all', 16),
                Http::bool('status', true) ? 1 : 0,
                Http::str('description', '', 255)
            );
            Event::log('config_save', '保存配置 ' . Http::str('config_key', '', 48), 'info', null, $who);
            Respond::ok(null, '配置已保存，客户端下次拉取即生效');
            break;

        case 'config.remove':
            Content::removeConfig(Http::str('config_key', '', 48));
            Event::log('config_remove', '删除配置 ' . Http::str('config_key', '', 48), 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        // ================= 公告 =================
        case 'announcements.list':
            Respond::ok(['items' => Content::announcementList(100)]);
            break;

        case 'announcements.save':
            $id = Http::int('id', 0) ?: null;
            $saved = Content::saveAnnouncement([
                'title' => Http::str('title', '', 128),
                'content' => Http::str('content', '', 4000),
                'level' => Http::str('level', 'info', 8),
                'platform' => Http::str('platform', 'all', 16),
                'min_version' => Http::str('min_version', '', 24),
                'max_version' => Http::str('max_version', '', 24),
                'start_at' => Http::str('start_at', '', 32),
                'end_at' => Http::str('end_at', '', 32),
                'status' => Http::bool('status', true),
            ], $id);
            Event::log('announcement_save', '保存公告 #' . $saved, 'info', null, $who);
            Respond::ok(['id' => $saved], '已保存');
            break;

        case 'announcements.remove':
            Content::removeAnnouncement(Http::int('id', 0));
            Event::log('announcement_remove', '删除公告', 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        // ================= 功德语 =================
        case 'blessings.list':
            Respond::ok(['items' => Content::blessings(200, Http::int('offset', 0))]);
            break;

        case 'blessings.save':
            $id = Http::int('id', 0) ?: null;
            $saved = Content::saveBlessing([
                'category' => Http::str('category', 'zen', 24),
                'content' => Http::str('content', '', 255),
                'source' => Http::str('source', '', 64),
                'weight' => Http::int('weight', 1),
                'status' => Http::bool('status', true),
            ], $id);
            Event::log('blessing_save', '保存功德语 #' . $saved, 'info', null, $who);
            Respond::ok(['id' => $saved], '已保存');
            break;

        case 'blessings.remove':
            Content::removeBlessing(Http::int('id', 0));
            Event::log('blessing_remove', '删除功德语', 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        // ================= 资源包 =================
        case 'assets.list':
            Respond::ok(['items' => Content::assetList(200)]);
            break;

        case 'assets.save':
            $id = Http::int('id', 0) ?: null;
            $saved = Content::saveAsset([
                'package_key' => Http::str('package_key', '', 48),
                'name' => Http::str('name', '', 64),
                'type' => Http::str('type', 'skin', 8),
                'platform' => Http::str('platform', 'all', 16),
                'version' => Http::str('version', '1.0.0', 24),
                'download_url' => Http::str('download_url', '', 255),
                'file_size' => Http::input('file_size', ''),
                'file_hash' => Http::str('file_hash', '', 128),
                'preview_url' => Http::str('preview_url', '', 255),
                'description' => Http::str('description', '', 255),
                'status' => Http::bool('status', true),
            ], $id);
            Event::log('asset_save', '保存资源包 #' . $saved, 'info', null, $who);
            Respond::ok(['id' => $saved], '已保存');
            break;

        case 'assets.remove':
            Content::removeAsset(Http::int('id', 0));
            Event::log('asset_remove', '删除资源包', 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        // ================= 反馈与崩溃 =================
        case 'feedback.list':
            $status = Http::input('status', '');
            Respond::ok([
                'items'   => Feedback::list(50, Http::int('offset', 0), $status === '' ? null : (int) $status),
                'pending' => Feedback::pendingCount(),
            ]);
            break;

        case 'feedback.mark':
            $id = Http::int('id', 0);
            $status = Http::int('status', 1);
            Feedback::mark($id, $status, Http::str('reply', '', 2000));
            Event::log('feedback_mark', '处理反馈 #' . $id . ' -> ' . $status, 'info', null, $who);
            Respond::ok(['id' => $id], '已更新');
            break;

        case 'feedback.remove':
            Feedback::remove(Http::int('id', 0));
            Event::log('feedback_remove', '删除反馈', 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        case 'crashes.list':
            Respond::ok(['items' => Feedback::crashList(50, Http::int('offset', 0)), 'total' => Feedback::crashCount()]);
            break;

        case 'crashes.purge':
            $days = max(1, Http::int('days', 30));
            $n = Feedback::purgeCrash($days);
            Event::log('crash_purge', '清理 ' . $days . ' 天前的崩溃上报，共 ' . $n . ' 条', 'warn', null, $who);
            Respond::ok(['removed' => $n], '已清理 ' . $n . ' 条');
            break;

        // ================= 审计与令牌 =================
        case 'events.list':
            Respond::ok(['items' => Event::recent(100, Http::int('offset', 0)), 'total' => Event::count()]);
            break;

        case 'tokens.list':
            Respond::ok(['items' => AdminAuth::tokenList()]);
            break;

        case 'tokens.create':
            $created = AdminAuth::createToken(
                Http::str('label', 'script', 64),
                Http::str('scope', 'read,write', 120),
                Http::int('ttl_days', 0) ?: null
            );
            Event::log('token_create', '创建访问令牌 ' . $created['id'], 'warn', null, $who);
            Respond::ok($created, '令牌已创建，请立即保存');
            break;

        case 'tokens.remove':
            AdminAuth::removeToken(Http::int('id', 0));
            Event::log('token_remove', '删除访问令牌', 'warn', null, $who);
            Respond::ok(null, '已删除');
            break;

        case 'logins.list':
            Respond::ok(['items' => AdminAuth::recentLogins(30)]);
            break;

        // ================= 维护 =================
        case 'maintenance':
            $task = Http::str('task', '', 32);
            $result = [];
            switch ($task) {
                case 'purge_buckets':
                    $result = Rate::purge();
                    break;
                case 'purge_online':
                    $result = ['online_sessions' => Online::purge()];
                    break;
                case 'purge_crash':
                    $result = ['crash_reports' => Feedback::purgeCrash(30)];
                    break;
                case 'purge_events':
                    $result = ['event_log' => Db::exec('DELETE FROM event_log WHERE created_at < DATE_SUB(NOW(), INTERVAL 60 DAY)')];
                    break;
                case 'recalc_global':
                    $result = recalcGlobal();
                    break;
                case 'vacuum_nonces':
                    $result = ['api_nonces' => Db::exec('DELETE FROM api_nonces WHERE expires_at < ?', [time()])];
                    break;
                default:
                    Respond::json(null, 40001, '未知的维护任务：' . $task, 400, 0, false);
            }
            Event::log('maintenance', '执行维护任务 ' . $task, 'info', null, $who);
            Respond::ok($result, '维护任务已完成');
            break;

        default:
            Respond::json(null, 40001, '未知操作：' . $action, 400, 0, false);
    }
} catch (\InvalidArgumentException $e) {
    Respond::json(null, 40001, $e->getMessage(), 400, 0, false);
} catch (\Throwable $e) {
    Event::exception($e);
    Respond::json(null, 50001, '服务端异常：' . (cfg('api.debug') ? $e->getMessage() : '请查看服务器日志'), 500, 0, false);
}

/** 从 devices / daily_active 重算 global_stats，用于数据核对 */
function recalcGlobal(): array
{
    $apps = AppKey::all();
    $count = 0;
    foreach ($apps as $app) {
        $appId = (int) $app['id'];
        $global = Db::one(
            'SELECT COALESCE(SUM(launches), 0) AS launches,
                    COALESCE(SUM(tap_delta), 0) AS taps,
                    COALESCE(SUM(merit_delta), 0) AS merit
             FROM daily_stats WHERE app_id = ?',
            [$appId]
        ) ?: ['launches' => 0, 'taps' => 0, 'merit' => 0];
        Stats::ensureGlobal($appId);
        Db::exec(
            'UPDATE global_stats SET launches = ?, taps = ?, merit = ?, updated_at = NOW() WHERE app_id = ?',
            [(int) $global['launches'], (int) $global['taps'], (int) $global['merit'], $appId]
        );
        $count++;
    }
    return ['apps' => $count];
}
