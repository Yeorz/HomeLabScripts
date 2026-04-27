-- WorkTrack Database Setup
-- Run as: mysql -u root -p < setup.sql

CREATE DATABASE IF NOT EXISTS worktrack
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE worktrack;

CREATE TABLE IF NOT EXISTS settings (
    id         INT  PRIMARY KEY DEFAULT 1,
    unit_system ENUM('metric','imperial') NOT NULL DEFAULT 'metric',
    theme       ENUM('dark','light')      NOT NULL DEFAULT 'dark'
) ENGINE=InnoDB;

INSERT INTO settings (id) VALUES (1)
ON DUPLICATE KEY UPDATE id = 1;

CREATE TABLE IF NOT EXISTS muscle_groups (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    name_nl VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

INSERT INTO muscle_groups (name_nl, name_en) VALUES
    ('Borst',           'Chest'),
    ('Rug',             'Back'),
    ('Schouders',       'Shoulders'),
    ('Biceps',          'Biceps'),
    ('Triceps',         'Triceps'),
    ('Onderarmen',      'Forearms'),
    ('Buikspieren',     'Abs / Core'),
    ('Quadriceps',      'Quadriceps'),
    ('Hamstrings',      'Hamstrings'),
    ('Bilspieren',      'Glutes'),
    ('Kuiten',          'Calves'),
    ('Volledig lichaam','Full Body'),
    ('Cardio',          'Cardio');

CREATE TABLE IF NOT EXISTS exercises (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    name_nl          VARCHAR(200) NOT NULL,
    name_en          VARCHAR(200),
    muscle_group_id  INT,
    category         ENUM('kracht','cardio','flexibiliteit','overig') NOT NULL DEFAULT 'kracht',
    equipment        ENUM('barbell','dumbbell','machine','cable','bodyweight','kettlebell','bands','cardio','overig') NOT NULL DEFAULT 'overig',
    is_custom        TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (muscle_group_id) REFERENCES muscle_groups(id)
) ENGINE=InnoDB;

INSERT INTO exercises (name_nl, name_en, muscle_group_id, category, equipment) VALUES
    -- Borst (20)
    ('Bankdrukken', 'Bench Press', 1, 'kracht', 'barbell'),
    ('Schuine bankdrukken', 'Incline Bench Press', 1, 'kracht', 'barbell'),
    ('Neerwaartse bankdrukken', 'Decline Bench Press', 1, 'kracht', 'barbell'),
    ('Dumbbell bankdrukken', 'Dumbbell Bench Press', 1, 'kracht', 'dumbbell'),
    ('Schuine dumbbell bankdrukken', 'Incline Dumbbell Bench Press', 1, 'kracht', 'dumbbell'),
    ('Neerwaartse dumbbell bankdrukken', 'Decline Dumbbell Bench Press', 1, 'kracht', 'dumbbell'),
    ('Dumbbell fly', 'Dumbbell Fly', 1, 'kracht', 'dumbbell'),
    ('Schuine dumbbell fly', 'Incline Dumbbell Fly', 1, 'kracht', 'dumbbell'),
    ('Cable crossover', 'Cable Crossover', 1, 'kracht', 'cable'),
    ('Hoge kabel fly', 'High Cable Fly', 1, 'kracht', 'cable'),
    ('Lage kabel fly', 'Low Cable Fly', 1, 'kracht', 'cable'),
    ('Push-ups', 'Push-ups', 1, 'kracht', 'bodyweight'),
    ('Neerwaartse push-ups', 'Decline Push-ups', 1, 'kracht', 'bodyweight'),
    ('Diamond push-ups', 'Diamond Push-ups', 1, 'kracht', 'bodyweight'),
    ('Brede push-ups', 'Wide Push-ups', 1, 'kracht', 'bodyweight'),
    ('Chest dips', 'Chest Dips', 1, 'kracht', 'bodyweight'),
    ('Machine chest press', 'Machine Chest Press', 1, 'kracht', 'machine'),
    ('Pec deck', 'Pec Deck / Machine Fly', 1, 'kracht', 'machine'),
    ('Svend press', 'Svend Press', 1, 'kracht', 'overig'),
    ('Landmine press', 'Landmine Press', 1, 'kracht', 'barbell'),
    -- Rug (20)
    ('Deadlift', 'Deadlift', 2, 'kracht', 'barbell'),
    ('Sumo deadlift', 'Sumo Deadlift', 2, 'kracht', 'barbell'),
    ('Rack pull', 'Rack Pull', 2, 'kracht', 'barbell'),
    ('Pull-ups', 'Pull-ups', 2, 'kracht', 'bodyweight'),
    ('Chin-ups', 'Chin-ups', 2, 'kracht', 'bodyweight'),
    ('Omgekeerde rij', 'Inverted Row', 2, 'kracht', 'bodyweight'),
    ('Barbell roeien', 'Barbell Row', 2, 'kracht', 'barbell'),
    ('Pendlay row', 'Pendlay Row', 2, 'kracht', 'barbell'),
    ('T-bar roeien', 'T-Bar Row', 2, 'kracht', 'barbell'),
    ('Dumbbell roeien', 'Dumbbell Row', 2, 'kracht', 'dumbbell'),
    ('Lat pulldown', 'Lat Pulldown', 2, 'kracht', 'cable'),
    ('Smalle grip lat pulldown', 'Close-Grip Lat Pulldown', 2, 'kracht', 'cable'),
    ('Seated cable row', 'Seated Cable Row', 2, 'kracht', 'cable'),
    ('Rechte arm pulldown', 'Straight-Arm Pulldown', 2, 'kracht', 'cable'),
    ('Face pulls', 'Face Pulls', 2, 'kracht', 'cable'),
    ('Machine roeien', 'Machine Row', 2, 'kracht', 'machine'),
    ('Hyperextensions', 'Hyperextensions', 2, 'kracht', 'machine'),
    ('Good mornings', 'Good Mornings', 2, 'kracht', 'barbell'),
    ('Shrug barbell', 'Barbell Shrug', 2, 'kracht', 'barbell'),
    ('Machine pullover', 'Machine Pullover', 2, 'kracht', 'machine'),
    -- Schouders (14)
    ('Militaire press', 'Military Press', 3, 'kracht', 'barbell'),
    ('Dumbbell schouderpress', 'Dumbbell Shoulder Press', 3, 'kracht', 'dumbbell'),
    ('Arnold press', 'Arnold Press', 3, 'kracht', 'dumbbell'),
    ('Machine schouderpress', 'Machine Shoulder Press', 3, 'kracht', 'machine'),
    ('Lateral raises', 'Lateral Raises', 3, 'kracht', 'dumbbell'),
    ('Front raises', 'Front Raises', 3, 'kracht', 'dumbbell'),
    ('Cable lateral raises', 'Cable Lateral Raises', 3, 'kracht', 'cable'),
    ('Achterste deltfly', 'Rear Delt Fly', 3, 'kracht', 'dumbbell'),
    ('Omgekeerde fly', 'Reverse Fly', 3, 'kracht', 'dumbbell'),
    ('Upright row', 'Upright Row', 3, 'kracht', 'barbell'),
    ('Dumbbell shrugs', 'Dumbbell Shrugs', 3, 'kracht', 'dumbbell'),
    ('Handstand push-ups', 'Handstand Push-ups', 3, 'kracht', 'bodyweight'),
    ('Cable rear delt fly', 'Cable Rear Delt Fly', 3, 'kracht', 'cable'),
    ('Seated dumbbell press', 'Seated Dumbbell Press', 3, 'kracht', 'dumbbell'),
    -- Biceps (12)
    ('Barbell curl', 'Barbell Curl', 4, 'kracht', 'barbell'),
    ('EZ-bar curl', 'EZ-Bar Curl', 4, 'kracht', 'barbell'),
    ('Dumbbell curl', 'Dumbbell Curl', 4, 'kracht', 'dumbbell'),
    ('Hamer curl', 'Hammer Curl', 4, 'kracht', 'dumbbell'),
    ('Zottman curl', 'Zottman Curl', 4, 'kracht', 'dumbbell'),
    ('Schuin dumbbell curl', 'Incline Dumbbell Curl', 4, 'kracht', 'dumbbell'),
    ('Concentratie curl', 'Concentration Curl', 4, 'kracht', 'dumbbell'),
    ('Spider curl', 'Spider Curl', 4, 'kracht', 'dumbbell'),
    ('Preacher curl', 'Preacher Curl', 4, 'kracht', 'machine'),
    ('Cable curl', 'Cable Curl', 4, 'kracht', 'cable'),
    ('Cable hamer curl', 'Cable Hammer Curl', 4, 'kracht', 'cable'),
    ('Reverse curl', 'Reverse Curl', 4, 'kracht', 'barbell'),
    -- Triceps (11)
    ('Triceps dips', 'Triceps Dips', 5, 'kracht', 'bodyweight'),
    ('Bench dips', 'Bench Dips', 5, 'kracht', 'bodyweight'),
    ('Close-grip bankdrukken', 'Close-Grip Bench Press', 5, 'kracht', 'barbell'),
    ('Skull crushers', 'Skull Crushers', 5, 'kracht', 'barbell'),
    ('JM press', 'JM Press', 5, 'kracht', 'barbell'),
    ('Triceps pushdown', 'Triceps Pushdown', 5, 'kracht', 'cable'),
    ('Overhead cable extension', 'Overhead Cable Extension', 5, 'kracht', 'cable'),
    ('Omgekeerd kabel pushdown', 'Reverse-Grip Pushdown', 5, 'kracht', 'cable'),
    ('Overhead dumbbell extension', 'Overhead Dumbbell Extension', 5, 'kracht', 'dumbbell'),
    ('Dumbbell kickback', 'Dumbbell Kickback', 5, 'kracht', 'dumbbell'),
    ('EZ-bar overhead extension', 'EZ-Bar Overhead Extension', 5, 'kracht', 'barbell'),
    -- Onderarmen (6)
    ('Polskrul', 'Wrist Curl', 6, 'kracht', 'barbell'),
    ('Omgekeerde polskrul', 'Reverse Wrist Curl', 6, 'kracht', 'barbell'),
    ('Farmer''s walk', 'Farmer''s Walk', 6, 'kracht', 'dumbbell'),
    ('Dead hang', 'Dead Hang', 6, 'kracht', 'bodyweight'),
    ('Plate pinch', 'Plate Pinch', 6, 'kracht', 'overig'),
    ('Onderarm rotatie', 'Forearm Rotation', 6, 'kracht', 'dumbbell'),
    -- Buikspieren (18)
    ('Crunches', 'Crunches', 7, 'kracht', 'bodyweight'),
    ('Sit-ups', 'Sit-ups', 7, 'kracht', 'bodyweight'),
    ('Plank', 'Plank', 7, 'kracht', 'bodyweight'),
    ('Zijplank', 'Side Plank', 7, 'kracht', 'bodyweight'),
    ('Leg raises', 'Leg Raises', 7, 'kracht', 'bodyweight'),
    ('Hangend beenheffen', 'Hanging Leg Raises', 7, 'kracht', 'bodyweight'),
    ('Russian twists', 'Russian Twists', 7, 'kracht', 'bodyweight'),
    ('Kabel crunches', 'Cable Crunches', 7, 'kracht', 'cable'),
    ('Ab wheel rollout', 'Ab Wheel Rollout', 7, 'kracht', 'overig'),
    ('Dead bug', 'Dead Bug', 7, 'kracht', 'bodyweight'),
    ('Mountain climbers', 'Mountain Climbers', 7, 'kracht', 'bodyweight'),
    ('Fiets crunches', 'Bicycle Crunches', 7, 'kracht', 'bodyweight'),
    ('Hollow body hold', 'Hollow Body Hold', 7, 'kracht', 'bodyweight'),
    ('V-ups', 'V-Ups', 7, 'kracht', 'bodyweight'),
    ('Dragon flag', 'Dragon Flag', 7, 'kracht', 'bodyweight'),
    ('Pallof press', 'Pallof Press', 7, 'kracht', 'cable'),
    ('L-sit', 'L-Sit', 7, 'kracht', 'bodyweight'),
    ('Windmill', 'Windmill', 7, 'kracht', 'kettlebell'),
    -- Quadriceps (17)
    ('Squats', 'Squats', 8, 'kracht', 'barbell'),
    ('Front squats', 'Front Squats', 8, 'kracht', 'barbell'),
    ('Box squat', 'Box Squat', 8, 'kracht', 'barbell'),
    ('Sumo squat', 'Sumo Squat', 8, 'kracht', 'barbell'),
    ('Paused squat', 'Paused Squat', 8, 'kracht', 'barbell'),
    ('Zercher squat', 'Zercher Squat', 8, 'kracht', 'barbell'),
    ('Goblet squat', 'Goblet Squat', 8, 'kracht', 'kettlebell'),
    ('Leg press', 'Leg Press', 8, 'kracht', 'machine'),
    ('Hack squat', 'Hack Squat', 8, 'kracht', 'machine'),
    ('Leg extension', 'Leg Extension', 8, 'kracht', 'machine'),
    ('Lunges', 'Lunges', 8, 'kracht', 'bodyweight'),
    ('Stappende lunges', 'Walking Lunges', 8, 'kracht', 'dumbbell'),
    ('Omgekeerde lunges', 'Reverse Lunges', 8, 'kracht', 'bodyweight'),
    ('Bulgaarse split squat', 'Bulgarian Split Squat', 8, 'kracht', 'dumbbell'),
    ('Step-ups', 'Step-Ups', 8, 'kracht', 'dumbbell'),
    ('Sissy squat', 'Sissy Squat', 8, 'kracht', 'bodyweight'),
    ('Wall sit', 'Wall Sit', 8, 'kracht', 'bodyweight'),
    -- Hamstrings (9)
    ('Romanian deadlift', 'Romanian Deadlift', 9, 'kracht', 'barbell'),
    ('Stiff-leg deadlift', 'Stiff-Leg Deadlift', 9, 'kracht', 'barbell'),
    ('Good mornings hamstrings', 'Good Mornings', 9, 'kracht', 'barbell'),
    ('Enkele been RDL', 'Single-Leg Romanian Deadlift', 9, 'kracht', 'dumbbell'),
    ('Liggende leg curl', 'Lying Leg Curl', 9, 'kracht', 'machine'),
    ('Zittende leg curl', 'Seated Leg Curl', 9, 'kracht', 'machine'),
    ('Nordic curls', 'Nordic Curls', 9, 'kracht', 'bodyweight'),
    ('Cable pull-through', 'Cable Pull-Through', 9, 'kracht', 'cable'),
    ('Swiss ball hamstring curl', 'Swiss Ball Hamstring Curl', 9, 'kracht', 'overig'),
    -- Bilspieren (10)
    ('Hip thrust', 'Hip Thrust', 10, 'kracht', 'barbell'),
    ('Banded hip thrust', 'Banded Hip Thrust', 10, 'kracht', 'bands'),
    ('Glute kickback', 'Glute Kickback', 10, 'kracht', 'cable'),
    ('Donkey kicks', 'Donkey Kicks', 10, 'kracht', 'bodyweight'),
    ('Zijwaartse beenheffen', 'Side-Lying Leg Raises', 10, 'kracht', 'bodyweight'),
    ('Clamshells', 'Clamshells', 10, 'kracht', 'bands'),
    ('Abductie machine', 'Hip Abduction Machine', 10, 'kracht', 'machine'),
    ('Adductie machine', 'Hip Adduction Machine', 10, 'kracht', 'machine'),
    ('Frog pumps', 'Frog Pumps', 10, 'kracht', 'bodyweight'),
    ('Glute bridge', 'Glute Bridge', 10, 'kracht', 'bodyweight'),
    -- Kuiten (6)
    ('Calf raises staand', 'Standing Calf Raises', 11, 'kracht', 'machine'),
    ('Calf raises zittend', 'Seated Calf Raises', 11, 'kracht', 'machine'),
    ('Ezelskalf raises', 'Donkey Calf Raises', 11, 'kracht', 'machine'),
    ('Enkele been calf raise', 'Single-Leg Calf Raise', 11, 'kracht', 'bodyweight'),
    ('Legpress calf raise', 'Leg Press Calf Raise', 11, 'kracht', 'machine'),
    ('Tibialis raises', 'Tibialis Raises', 11, 'kracht', 'bodyweight'),
    -- Volledig lichaam (16)
    ('Burpees', 'Burpees', 12, 'kracht', 'bodyweight'),
    ('Turkish get-up', 'Turkish Get-Up', 12, 'kracht', 'kettlebell'),
    ('Clean and jerk', 'Clean and Jerk', 12, 'kracht', 'barbell'),
    ('Snatch', 'Snatch', 12, 'kracht', 'barbell'),
    ('Power clean', 'Power Clean', 12, 'kracht', 'barbell'),
    ('Kettlebell swing', 'Kettlebell Swing', 12, 'kracht', 'kettlebell'),
    ('Thruster', 'Thruster', 12, 'kracht', 'barbell'),
    ('Manmaker', 'Man Maker', 12, 'kracht', 'dumbbell'),
    ('Devil''s press', 'Devil''s Press', 12, 'kracht', 'dumbbell'),
    ('Farmer''s carry', 'Farmer''s Carry', 12, 'kracht', 'dumbbell'),
    ('Bear crawl', 'Bear Crawl', 12, 'kracht', 'bodyweight'),
    ('Sled push', 'Sled Push', 12, 'kracht', 'overig'),
    ('Sled pull', 'Sled Pull', 12, 'kracht', 'overig'),
    ('Battle ropes', 'Battle Ropes', 12, 'kracht', 'overig'),
    ('Box jumps', 'Box Jumps', 12, 'kracht', 'bodyweight'),
    ('Kettlebell clean', 'Kettlebell Clean', 12, 'kracht', 'kettlebell'),
    -- Cardio (15)
    ('Hardlopen', 'Running', 13, 'cardio', 'cardio'),
    ('Sprints', 'Sprints', 13, 'cardio', 'cardio'),
    ('Wandelen', 'Walking', 13, 'cardio', 'cardio'),
    ('Fietsen', 'Cycling', 13, 'cardio', 'cardio'),
    ('Roeimachine', 'Rowing Machine', 13, 'cardio', 'cardio'),
    ('Crosstrainer', 'Elliptical', 13, 'cardio', 'cardio'),
    ('Springtouw', 'Jump Rope', 13, 'cardio', 'cardio'),
    ('Zwemmen', 'Swimming', 13, 'cardio', 'cardio'),
    ('HIIT', 'HIIT', 13, 'cardio', 'cardio'),
    ('Traplopen', 'Stair Climbing', 13, 'cardio', 'cardio'),
    ('Ski erg', 'Ski Erg', 13, 'cardio', 'cardio'),
    ('Air bike', 'Air Bike', 13, 'cardio', 'cardio'),
    ('Loopband', 'Treadmill', 13, 'cardio', 'cardio'),
    ('Zwemmen banen', 'Lap Swimming', 13, 'cardio', 'cardio'),
    ('Stepping machine', 'Stair Stepper', 13, 'cardio', 'cardio');

-- Users — required for mobile / watch authentication and web sign-in
-- email, name, oauth_id are stored AES-256-GCM encrypted.
-- email_hash and oauth_search are HMAC blind indexes for WHERE lookups.
CREATE TABLE IF NOT EXISTS users (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    email          TEXT,                      -- encrypted; use email_hash for lookups
    email_hash     VARCHAR(64) UNIQUE,        -- searchHash(email) — for login/register checks
    name           TEXT,                      -- encrypted
    password       VARCHAR(255),              -- bcrypt hash; NULL for OAuth-only users
    oauth_provider VARCHAR(20),               -- plain: 'google' | 'facebook' | 'apple'
    oauth_id       TEXT,                      -- encrypted provider user ID
    oauth_search   VARCHAR(64),               -- searchHash(provider:oauth_id) — for OAuth lookups
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY idx_oauth_search (oauth_search)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS workouts (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT,
    name             TEXT,                         -- encrypted
    date             DATE     NOT NULL,            -- plain: needed for time-range queries
    start_time       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time         DATETIME,
    workout_type     VARCHAR(50),                  -- plain enum-like value
    calories         INT,                          -- plain: needed for analytics aggregations
    duration_seconds INT,                          -- plain: needed for analytics
    notes            TEXT,                         -- encrypted
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS workout_exercises (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    workout_id   INT NOT NULL,
    exercise_id  INT,
    custom_name  TEXT,                       -- encrypted
    order_index  INT NOT NULL DEFAULT 0,
    notes        TEXT,                       -- encrypted
    FOREIGN KEY (workout_id)  REFERENCES workouts(id)  ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sets (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    workout_exercise_id  INT NOT NULL,
    set_number           INT NOT NULL,
    weight_kg            DECIMAL(6,2),       -- plain: needed for volume calculations
    reps                 INT,                -- plain: needed for volume calculations
    duration_seconds     INT,                -- plain: needed for cardio analytics
    distance_km          DECIMAL(8,3),       -- plain: needed for cardio analytics
    rpe                  TINYINT,            -- plain: low-sensitivity numeric
    is_warmup            TINYINT(1) NOT NULL DEFAULT 0,
    notes                TEXT,               -- encrypted (was VARCHAR(255))
    FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
) ENGINE=InnoDB;
