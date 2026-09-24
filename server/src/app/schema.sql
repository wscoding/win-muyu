-- ============================================================
-- wid.chr.cc（Prue Widgets 后端）表结构
-- 目标环境：MySQL 5.7.44 / utf8mb4
-- 用法：mysql wid < schema.sql   （脚本见 Scripts/init_wid_db.py）
-- 说明：所有 DDL 均幂等（IF NOT EXISTS），重复执行安全。
-- ============================================================

SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- 1. 应用（客户端）注册表
--    app_key 公开、app_secret 作为 HMAC 密钥，两者分离是这套鉴权的基础。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `apps` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_key` CHAR(32) NOT NULL COMMENT '客户端标识（随客户端公开分发）',
  `app_secret` CHAR(64) NOT NULL COMMENT 'HMAC-SHA256 签名密钥',
  `name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '应用名',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1=启用 0=停用',
  `rate_limit_per_min` INT UNSIGNED NOT NULL DEFAULT 600 COMMENT '单设备每分钟请求上限',
  `request_total` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '累计有效请求数',
  `note` VARCHAR(120) NOT NULL DEFAULT '',
  `last_used_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_app_key` (`app_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户端应用注册表';

-- ------------------------------------------------------------
-- 2. 设备（客户端实例）
--    匿名标识，由客户端本地随机生成并持久化，不是硬件指纹。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `devices` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NOT NULL,
  `device_id` VARCHAR(64) NOT NULL COMMENT '客户端生成的匿名设备标识',
  `platform` VARCHAR(16) NOT NULL DEFAULT '' COMMENT 'windows/macos/android/ios/web/other',
  `os_version` VARCHAR(32) NOT NULL DEFAULT '',
  `client_version` VARCHAR(24) NOT NULL DEFAULT '',
  `channel` VARCHAR(16) NOT NULL DEFAULT '' COMMENT 'release/beta',
  `color` VARCHAR(8) NOT NULL DEFAULT '' COMMENT '木鱼配色 black/white',
  `nickname` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '功德榜昵称（需 opt-in）',
  `rank_opt_in` TINYINT NOT NULL DEFAULT 0 COMMENT '1=参与功德榜（默认不参与）',
  `launch_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `session_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `tap_total` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '服务端累计敲击（增量累加）',
  `merit_total` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '服务端累计功德',
  `snapshot_tap_total` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '客户端上报的累计敲击快照',
  `snapshot_merit_total` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '客户端上报的累计功德快照',
  `first_seen_at` DATETIME NOT NULL,
  `last_seen_at` DATETIME NOT NULL,
  `last_ip` VARBINARY(16) NULL,
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '1=正常 0=封禁',
  `note` VARCHAR(120) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_app_device` (`app_id`,`device_id`),
  KEY `idx_last_seen` (`last_seen_at`),
  KEY `idx_platform` (`platform`),
  KEY `idx_client_version` (`client_version`),
  KEY `idx_rank` (`rank_opt_in`,`tap_total`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户端设备（匿名）';

-- ------------------------------------------------------------
-- 3. 在线会话（心跳 + 时间窗，不依赖"退出 -1"）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `online_sessions` (
  `device_pk` BIGINT UNSIGNED NOT NULL,
  `app_id` INT UNSIGNED NOT NULL,
  `session_id` VARCHAR(64) NOT NULL DEFAULT '',
  `platform` VARCHAR(16) NOT NULL DEFAULT '',
  `started_at` INT UNSIGNED NOT NULL COMMENT 'unix 秒',
  `last_beat_at` INT UNSIGNED NOT NULL COMMENT 'unix 秒',
  `ip` VARBINARY(16) NULL,
  PRIMARY KEY (`device_pk`),
  KEY `idx_beat` (`last_beat_at`),
  KEY `idx_app_platform` (`app_id`,`platform`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='在线会话（按心跳时间窗判定）';

-- ------------------------------------------------------------
-- 4. 每日聚合（趋势图数据源）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `daily_stats` (
  `stat_date` DATE NOT NULL,
  `app_id` INT UNSIGNED NOT NULL,
  `platform` VARCHAR(16) NOT NULL DEFAULT 'other',
  `launches` INT UNSIGNED NOT NULL DEFAULT 0,
  `tap_delta` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `merit_delta` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `active_devices` INT UNSIGNED NOT NULL DEFAULT 0,
  `heartbeats` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`stat_date`,`app_id`,`platform`),
  KEY `idx_date` (`stat_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日聚合统计';

-- ------------------------------------------------------------
-- 5. 每日活跃设备（去重口径，也是功德榜的数据源）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `daily_active` (
  `stat_date` DATE NOT NULL,
  `app_id` INT UNSIGNED NOT NULL,
  `device_pk` BIGINT UNSIGNED NOT NULL,
  `platform` VARCHAR(16) NOT NULL DEFAULT '',
  `launches` INT UNSIGNED NOT NULL DEFAULT 0,
  `tap_delta` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`stat_date`,`app_id`,`device_pk`),
  KEY `idx_device` (`device_pk`,`stat_date`),
  KEY `idx_platform` (`stat_date`,`platform`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日活跃设备（去重）';

-- ------------------------------------------------------------
-- 6. 全量累计
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `global_stats` (
  `app_id` INT UNSIGNED NOT NULL,
  `launches` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `taps` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `merit` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `online_now` INT UNSIGNED NOT NULL DEFAULT 0,
  `online_peak` INT UNSIGNED NOT NULL DEFAULT 0,
  `online_peak_at` DATETIME NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`app_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='全量累计统计';

-- ------------------------------------------------------------
-- 7. 版本发布（App 更新检测的数据源）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `app_releases` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NOT NULL,
  `platform` VARCHAR(16) NOT NULL COMMENT 'windows/macos/android/ios',
  `channel` VARCHAR(16) NOT NULL DEFAULT 'release' COMMENT 'release/beta',
  `version` VARCHAR(24) NOT NULL,
  `build_number` VARCHAR(24) NOT NULL DEFAULT '',
  `build_signature` VARCHAR(64) NOT NULL DEFAULT '',
  `appbuild` DATE NULL,
  `installer_store` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '分发渠道，如 官网 / App Store',
  `newlog` TEXT COMMENT '该版本的更新说明',
  `download_url` VARCHAR(255) NOT NULL DEFAULT '',
  `file_size` BIGINT UNSIGNED NULL,
  `file_hash` VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'sha256:xxxx',
  `min_supported_version` VARCHAR(24) NOT NULL DEFAULT '' COMMENT '低于此版本强制升级',
  `force_upgrade` TINYINT NOT NULL DEFAULT 0,
  `is_latest` TINYINT NOT NULL DEFAULT 0 COMMENT '同平台同渠道唯一',
  `published_at` DATETIME NOT NULL,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_release` (`app_id`,`platform`,`channel`,`version`),
  KEY `idx_latest` (`app_id`,`platform`,`channel`,`is_latest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='版本发布记录';

-- ------------------------------------------------------------
-- 8. 更新日志
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `changelog_entries` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=全局',
  `release_id` INT UNSIGNED NULL,
  `version` VARCHAR(24) NOT NULL DEFAULT '',
  `platform` VARCHAR(16) NOT NULL DEFAULT 'all',
  `channel` VARCHAR(16) NOT NULL DEFAULT 'release',
  `kind` VARCHAR(12) NOT NULL DEFAULT 'feature' COMMENT 'feature/fix/improve/notice/breaking',
  `title` VARCHAR(128) NOT NULL DEFAULT '',
  `body` TEXT,
  `released_at` DATE NOT NULL,
  `published` TINYINT NOT NULL DEFAULT 1,
  `sort_weight` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_date` (`released_at`),
  KEY `idx_pub` (`published`,`released_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='更新日志';

-- ------------------------------------------------------------
-- 9. 签名防重放
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `api_nonces` (
  `nonce_hash` CHAR(40) NOT NULL,
  `app_id` INT UNSIGNED NOT NULL,
  `created_at` INT UNSIGNED NOT NULL,
  `expires_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`nonce_hash`),
  KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='接口 nonce（防重放）';

-- ------------------------------------------------------------
-- 10. 限流计数桶
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rate_buckets` (
  `bucket_key` CHAR(41) NOT NULL,
  `scope` VARCHAR(16) NOT NULL DEFAULT '',
  `hits` INT UNSIGNED NOT NULL DEFAULT 0,
  `window_start` INT UNSIGNED NOT NULL,
  `expires_at` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`bucket_key`),
  KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='滑动窗口限流计数';

-- ------------------------------------------------------------
-- 11. 事件 / 审计日志
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `event_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NULL,
  `level` VARCHAR(8) NOT NULL DEFAULT 'info' COMMENT 'info/warn/error',
  `event` VARCHAR(48) NOT NULL,
  `message` VARCHAR(255) NOT NULL DEFAULT '',
  `ip` VARBINARY(16) NULL,
  `actor` VARCHAR(48) NOT NULL DEFAULT '',
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_created` (`created_at`),
  KEY `idx_event` (`event`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='事件与审计日志';

-- ------------------------------------------------------------
-- 12. 后台访问令牌（给脚本 / CI 用，可选）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_tokens` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` CHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL DEFAULT '',
  `scope` VARCHAR(120) NOT NULL DEFAULT 'read' COMMENT 'read/write，逗号分隔',
  `expires_at` DATETIME NULL,
  `last_used_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_token` (`token_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台访问令牌';

-- ------------------------------------------------------------
-- 13. 功德语 / 每日一签
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `blessings` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(24) NOT NULL DEFAULT 'zen' COMMENT 'zen 禅语 / merit 功德 / humor 摸鱼',
  `content` VARCHAR(255) NOT NULL,
  `source` VARCHAR(64) NOT NULL DEFAULT '',
  `weight` SMALLINT NOT NULL DEFAULT 1,
  `status` TINYINT NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cat` (`category`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='功德语 / 每日一签';

-- ------------------------------------------------------------
-- 14. 公告
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `announcements` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(128) NOT NULL,
  `content` TEXT,
  `level` VARCHAR(8) NOT NULL DEFAULT 'info' COMMENT 'info/notice/warn',
  `platform` VARCHAR(16) NOT NULL DEFAULT 'all',
  `min_version` VARCHAR(24) NOT NULL DEFAULT '',
  `max_version` VARCHAR(24) NOT NULL DEFAULT '',
  `start_at` DATETIME NULL,
  `end_at` DATETIME NULL,
  `status` TINYINT NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_window` (`status`,`start_at`,`end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户端公告';

-- ------------------------------------------------------------
-- 15. 运行时配置（下发给客户端，改配置不发版）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `app_config` (
  `config_key` VARCHAR(48) NOT NULL,
  `config_value` TEXT,
  `value_type` VARCHAR(12) NOT NULL DEFAULT 'string' COMMENT 'string/int/float/bool/json',
  `platform` VARCHAR(16) NOT NULL DEFAULT 'all',
  `status` TINYINT NOT NULL DEFAULT 1,
  `description` VARCHAR(255) NOT NULL DEFAULT '',
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户端运行时配置';

-- ------------------------------------------------------------
-- 16. 资源包（皮肤 / 音效包 / 字体）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `asset_packages` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `package_key` VARCHAR(48) NOT NULL,
  `name` VARCHAR(64) NOT NULL DEFAULT '',
  `type` VARCHAR(8) NOT NULL DEFAULT 'skin' COMMENT 'skin/sound/font',
  `platform` VARCHAR(16) NOT NULL DEFAULT 'all',
  `version` VARCHAR(24) NOT NULL DEFAULT '1.0.0',
  `download_url` VARCHAR(255) NOT NULL DEFAULT '',
  `file_size` BIGINT UNSIGNED NULL,
  `file_hash` VARCHAR(128) NOT NULL DEFAULT '',
  `preview_url` VARCHAR(255) NOT NULL DEFAULT '',
  `description` VARCHAR(255) NOT NULL DEFAULT '',
  `status` TINYINT NOT NULL DEFAULT 1,
  `published_at` DATETIME NOT NULL,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_package` (`package_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='皮肤 / 音效包清单';

-- ------------------------------------------------------------
-- 17. 用户反馈
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `feedback` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `device_pk` BIGINT UNSIGNED NULL,
  `device_id` VARCHAR(64) NOT NULL DEFAULT '',
  `category` VARCHAR(24) NOT NULL DEFAULT 'other',
  `contact` VARCHAR(120) NOT NULL DEFAULT '',
  `content` TEXT,
  `client_version` VARCHAR(24) NOT NULL DEFAULT '',
  `platform` VARCHAR(16) NOT NULL DEFAULT '',
  `os_version` VARCHAR(32) NOT NULL DEFAULT '',
  `ip` VARBINARY(16) NULL,
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0=未读 1=已读 2=已处理',
  `reply` TEXT,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户反馈';

-- ------------------------------------------------------------
-- 18. 崩溃上报
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `crash_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `app_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `device_pk` BIGINT UNSIGNED NULL,
  `device_id` VARCHAR(64) NOT NULL DEFAULT '',
  `fingerprint` CHAR(40) NOT NULL COMMENT '去重指纹',
  `error_type` VARCHAR(64) NOT NULL DEFAULT '',
  `message` VARCHAR(255) NOT NULL DEFAULT '',
  `detail` TEXT,
  `client_version` VARCHAR(24) NOT NULL DEFAULT '',
  `platform` VARCHAR(16) NOT NULL DEFAULT '',
  `os_version` VARCHAR(32) NOT NULL DEFAULT '',
  `ip` VARBINARY(16) NULL,
  `occur_count` INT UNSIGNED NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL,
  `last_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_fp` (`fingerprint`,`created_at`),
  KEY `idx_last` (`last_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='崩溃上报';

-- ------------------------------------------------------------
-- 19. 设置云同步
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `device_settings` (
  `device_pk` BIGINT UNSIGNED NOT NULL,
  `app_id` INT UNSIGNED NOT NULL,
  `payload` MEDIUMTEXT,
  `revision` INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`device_pk`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设置云同步（乐观锁）';

-- ------------------------------------------------------------
-- 20. 后台会话（记录登录，用于风控与"最近登录"展示）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_logins` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ip` VARBINARY(16) NULL,
  `ua` VARCHAR(255) NOT NULL DEFAULT '',
  `success` TINYINT NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台登录记录';
