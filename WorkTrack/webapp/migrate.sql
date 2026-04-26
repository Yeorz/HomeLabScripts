-- WorkTrack Migration — run this on an existing installation
-- Run as: mysql -u root -p worktrack < webapp/migrate.sql

USE worktrack;

-- Users table (new)
CREATE TABLE IF NOT EXISTS users (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(255) UNIQUE NOT NULL,
    password   VARCHAR(255)        NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

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
