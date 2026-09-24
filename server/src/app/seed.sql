-- ============================================================
-- wid.chr.cc 初始内容
-- 依赖 schema.sql 已执行；app_id = 1（初始化脚本创建的默认应用）
-- 幂等性说明：本文件用 INSERT IGNORE / 唯一键约束保证可重复执行。
-- ============================================================

SET NAMES utf8mb4;

-- ---------------- 功德语 / 每日一签 ----------------
INSERT IGNORE INTO `blessings` (`id`, `category`, `content`, `source`, `weight`, `status`, `created_at`) VALUES
(1,  'zen',   '心若不动，风又奈何；你若不伤，岁月无恙。', '六祖坛经', 1, 1, NOW()),
(2,  'zen',   '一切有为法，如梦幻泡影，如露亦如电，应作如是观。', '金刚经', 1, 1, NOW()),
(3,  'zen',   '菩提本无树，明镜亦非台。本来无一物，何处惹尘埃。', '六祖慧能', 1, 1, NOW()),
(4,  'zen',   '行到水穷处，坐看云起时。', '王维', 1, 1, NOW()),
(5,  'zen',   '不急不躁，慢慢来，一切都来得及。', '内置', 1, 1, NOW()),
(6,  'zen',   '烦恼即菩提，把今天的烦恼敲成今天的功德。', '内置', 1, 1, NOW()),
(7,  'merit', '功德不必外求，敲一下便有一分。', '内置', 1, 1, NOW()),
(8,  'merit', '今日功德已入账，愿你被世界温柔以待。', '内置', 1, 1, NOW()),
(9,  'merit', '积跬步以至千里，积敲击以至功德无量。', '内置', 1, 1, NOW()),
(10, 'humor', '老板看不见的地方，就是修行的道场。', '内置', 1, 1, NOW()),
(11, 'humor', '敲木鱼不是为了功德，是为了让会议更快结束。', '内置', 1, 1, NOW()),
(12, 'humor', '今天也很努力地摸鱼了，辛苦了。', '内置', 1, 1, NOW());

-- ---------------- 运行时配置 ----------------
INSERT INTO `app_config` (`config_key`, `config_value`, `value_type`, `platform`, `status`, `description`, `updated_at`) VALUES
('heartbeatInterval',   '60',    'int',    'all',     1, '心跳间隔（秒），决定在线判定的精度', NOW()),
('tapBatchSize',        '20',    'int',    'all',     1, '敲击攒够多少次上报一次', NOW()),
('tapBatchIntervalMs',  '5000',  'int',    'all',     1, '敲击上报的最大等待时间（毫秒）', NOW()),
('autoTapMinIntervalMs','150',   'int',    'all',     1, '自动敲击的最小间隔（毫秒）', NOW()),
('meritPerTap',         '100',   'int',    'all',     1, '每多少次敲击记 1 功德', NOW()),
('enableLeaderboard',   '1',     'bool',   'all',     1, '是否开放功德榜入口', NOW()),
('enableBlessing',      '1',     'bool',   'all',     1, '是否启用每日一签', NOW()),
('enableFeedback',      '1',     'bool',   'all',     1, '是否显示反馈入口', NOW()),
('updateCheckIntervalH', '12',   'int',    'all',     1, '自动检查更新的间隔（小时）', NOW()),
('defaultVolume',       '0.8',   'float',  'all',     1, '默认音量', NOW()),
('defaultSoundPack',    'muyu',  'string', 'all',     1, '默认音效包标识', NOW()),
('defaultSkin',         'classic','string','all',     1, '默认木鱼皮肤标识', NOW()),
('tipTemplates',        '["功德 +1","心静 +1","摸鱼 +1","禅心 +1"]', 'json', 'all', 1, '功德提示浮层文案池', NOW()),
('announcementPollMin', '30',    'int',    'all',     1, '公告轮询间隔（分钟）', NOW())
ON DUPLICATE KEY UPDATE `description` = VALUES(`description`);

-- ---------------- 公告 ----------------
INSERT IGNORE INTO `announcements` (`id`, `title`, `content`, `level`, `platform`, `min_version`, `max_version`, `start_at`, `end_at`, `status`, `created_at`) VALUES
(1, '新后端已上线', '统计接口迁移至 HTTPS，并新增功德榜、每日一签与云同步设置。首次启动会自动注册设备，无需任何操作。', 'info', 'all', '', '', NULL, NULL, 1, NOW());

-- ---------------- 版本发布（初始版本，供下载页与更新检测使用） ----------------
INSERT INTO `app_releases`
  (`app_id`, `platform`, `channel`, `version`, `build_number`, `build_signature`, `appbuild`, `installer_store`,
   `newlog`, `download_url`, `file_size`, `file_hash`, `min_supported_version`, `force_upgrade`,
   `is_latest`, `published_at`, `created_at`, `updated_at`)
VALUES
(1, 'windows', 'release', '3.0.0', '300', '2026-09-23', '2026-09-23', '官网',
 '桌面电子木鱼 3.0.0：重构统计后端、支持 macOS、新增每日一签与功德榜。',
 'https://wid.chr.cc/download', NULL, '', '3.0.0', 0, 1, NOW(), NOW(), NOW()),
(1, 'macos', 'release', '3.0.0', '300', '2026-09-23', '2026-09-23', '官网',
 '桌面电子木鱼 3.0.0：重构统计后端、支持 macOS、新增每日一签与功德榜。',
 'https://wid.chr.cc/download', NULL, '', '3.0.0', 0, 1, NOW(), NOW(), NOW())
ON DUPLICATE KEY UPDATE `newlog` = VALUES(`newlog`);

-- ---------------- 更新日志 ----------------
-- 该表无自然唯一键，故显式指定 id + INSERT IGNORE 保证可重复执行。
INSERT IGNORE INTO `changelog_entries`
  (`id`, `app_id`, `release_id`, `version`, `platform`, `channel`, `kind`, `title`, `body`, `released_at`, `published`, `sort_weight`, `created_at`)
VALUES
(1, 1, NULL, '3.0.0', 'all', 'release', 'feature', '全新统计后端',
 '统计接口全面重写：启用 HTTPS、HMAC 签名鉴权、批量敲击上报，并新增功德榜与每日一签。', CURDATE(), 1, 10, NOW()),
(2, 1, NULL, '3.0.0', 'windows', 'release', 'feature', 'Windows 桌面端支持',
 '无边框悬浮窗、透明背景、置顶显示，不进任务栏；右键打开设置面板。', CURDATE(), 1, 9, NOW()),
(3, 1, NULL, '3.0.0', 'macos', 'release', 'feature', 'macOS 原生适配',
 '修复窗口透明背景、单实例与文件选择器权限问题。', CURDATE(), 1, 8, NOW()),
(4, 1, NULL, '3.0.0', 'all', 'release', 'improve', '敲击响应优化',
 '上报与敲击响应彻底解耦：网络不通时敲击依然即时，不会有任何卡顿。', CURDATE(), 1, 7, NOW());
