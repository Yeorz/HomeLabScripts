-- WorkTrack Migration — run this on an existing installation
-- Run as: mysql -u root -p worktrack < webapp/migrate.sql

USE worktrack;

-- Users table (new — skip if already exists)
CREATE TABLE IF NOT EXISTS users (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    email          VARCHAR(255) UNIQUE,
    name           VARCHAR(200),
    password       VARCHAR(255),
    oauth_provider VARCHAR(20),
    oauth_id       VARCHAR(255),
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY idx_oauth (oauth_provider, oauth_id)
) ENGINE=InnoDB;

-- Existing users table: add OAuth columns (safe to run multiple times)
ALTER TABLE users
    MODIFY COLUMN password    VARCHAR(255) NULL,
    ADD COLUMN IF NOT EXISTS name           VARCHAR(200)  AFTER email,
    ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR(20)   AFTER password,
    ADD COLUMN IF NOT EXISTS oauth_id       VARCHAR(255)  AFTER oauth_provider;

-- Add unique index for OAuth lookup if not already present
SET @idx = (SELECT COUNT(*) FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_oauth');
SET @sql = IF(@idx = 0,
    'ALTER TABLE users ADD UNIQUE KEY idx_oauth (oauth_provider, oauth_id)',
    'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Add mobile-compatibility columns to workouts
ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS user_id          INT          AFTER id,
    ADD COLUMN IF NOT EXISTS workout_type     VARCHAR(50)  AFTER notes,
    ADD COLUMN IF NOT EXISTS calories         INT          AFTER workout_type,
    ADD COLUMN IF NOT EXISTS duration_seconds INT          AFTER calories;

-- Add foreign key only if it does not already exist
SET @fk_exists = (
    SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'workouts'
      AND COLUMN_NAME  = 'user_id'
      AND REFERENCED_TABLE_NAME = 'users'
);
SET @sql = IF(@fk_exists = 0,
    'ALTER TABLE workouts ADD CONSTRAINT fk_workouts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
