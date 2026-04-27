-- WorkTrack Migration — run on an existing installation
-- Run as: mysql -u root -p worktrack < webapp/migrate.sql
-- After this, run: php webapp/migrate_encrypt.php  (encrypts existing plain-text rows)

USE worktrack;

-- ── Users table ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    email          TEXT,
    email_hash     VARCHAR(64) UNIQUE,
    name           TEXT,
    password       VARCHAR(255),
    oauth_provider VARCHAR(20),
    oauth_id       TEXT,
    oauth_search   VARCHAR(64),
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY idx_oauth_search (oauth_search)
) ENGINE=InnoDB;

-- Widen / add columns to existing users table
ALTER TABLE users
    MODIFY COLUMN password    VARCHAR(255)  NULL,
    MODIFY COLUMN email       TEXT,
    MODIFY COLUMN name        TEXT,
    ADD COLUMN IF NOT EXISTS email_hash     VARCHAR(64)  AFTER email,
    ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR(20)  AFTER password,
    ADD COLUMN IF NOT EXISTS oauth_id       TEXT         AFTER oauth_provider,
    ADD COLUMN IF NOT EXISTS oauth_search   VARCHAR(64)  AFTER oauth_id;

-- Blind-index unique keys (add only if absent)
SET @e = (SELECT COUNT(*) FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_email_hash');
SET @sql = IF(@e = 0,
    'ALTER TABLE users ADD UNIQUE KEY idx_email_hash (email_hash)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @o = (SELECT COUNT(*) FROM information_schema.STATISTICS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_oauth_search');
SET @sql = IF(@o = 0,
    'ALTER TABLE users ADD UNIQUE KEY idx_oauth_search (oauth_search)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── Workouts table ────────────────────────────────────────────────────────
ALTER TABLE workouts
    MODIFY COLUMN name   TEXT,
    MODIFY COLUMN notes  TEXT,
    ADD COLUMN IF NOT EXISTS user_id          INT          AFTER id,
    ADD COLUMN IF NOT EXISTS workout_type     VARCHAR(50)  AFTER notes,
    ADD COLUMN IF NOT EXISTS calories         INT          AFTER workout_type,
    ADD COLUMN IF NOT EXISTS duration_seconds INT          AFTER calories;

SET @fk = (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'workouts'
             AND COLUMN_NAME = 'user_id' AND REFERENCED_TABLE_NAME = 'users');
SET @sql = IF(@fk = 0,
    'ALTER TABLE workouts ADD CONSTRAINT fk_workouts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── Workout exercises table ───────────────────────────────────────────────
ALTER TABLE workout_exercises
    MODIFY COLUMN custom_name TEXT,
    MODIFY COLUMN notes       TEXT;

-- ── Sets table ────────────────────────────────────────────────────────────
ALTER TABLE sets
    MODIFY COLUMN notes TEXT;
