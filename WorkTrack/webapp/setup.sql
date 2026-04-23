-- WorkTrack Database Setup
-- Voer uit als: mysql -u root -p < setup.sql

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
    -- Borst
    ('Bankdrukken',          'Bench Press',          1, 'kracht', 'barbell'),
    ('Schuine bankdrukken',  'Incline Bench Press',  1, 'kracht', 'barbell'),
    ('Dumbbell bankdrukken', 'Dumbbell Bench Press', 1, 'kracht', 'dumbbell'),
    ('Dumbbell fly',         'Dumbbell Fly',         1, 'kracht', 'dumbbell'),
    ('Push-ups',             'Push-ups',             1, 'kracht', 'bodyweight'),
    ('Cable crossover',      'Cable Crossover',      1, 'kracht', 'cable'),
    -- Rug
    ('Deadlift',             'Deadlift',             2, 'kracht', 'barbell'),
    ('Pull-ups',             'Pull-ups',             2, 'kracht', 'bodyweight'),
    ('Chin-ups',             'Chin-ups',             2, 'kracht', 'bodyweight'),
    ('Barbell roeien',       'Barbell Row',          2, 'kracht', 'barbell'),
    ('Dumbbell roeien',      'Dumbbell Row',         2, 'kracht', 'dumbbell'),
    ('Lat pulldown',         'Lat Pulldown',         2, 'kracht', 'cable'),
    ('Seated cable row',     'Seated Cable Row',     2, 'kracht', 'cable'),
    -- Schouders
    ('Militaire press',           'Military Press',          3, 'kracht', 'barbell'),
    ('Dumbbell schouderpress',    'Dumbbell Shoulder Press', 3, 'kracht', 'dumbbell'),
    ('Lateral raises',            'Lateral Raises',          3, 'kracht', 'dumbbell'),
    ('Front raises',              'Front Raises',            3, 'kracht', 'dumbbell'),
    ('Arnold press',              'Arnold Press',            3, 'kracht', 'dumbbell'),
    -- Biceps
    ('Barbell curl',   'Barbell Curl',   4, 'kracht', 'barbell'),
    ('Dumbbell curl',  'Dumbbell Curl',  4, 'kracht', 'dumbbell'),
    ('Hamer curl',     'Hammer Curl',    4, 'kracht', 'dumbbell'),
    ('Preacher curl',  'Preacher Curl',  4, 'kracht', 'machine'),
    -- Triceps
    ('Triceps dips',                  'Triceps Dips',                 5, 'kracht', 'bodyweight'),
    ('Close-grip bankdrukken',        'Close-Grip Bench Press',       5, 'kracht', 'barbell'),
    ('Skull crushers',                'Skull Crushers',                5, 'kracht', 'barbell'),
    ('Triceps pushdown',              'Triceps Pushdown',              5, 'kracht', 'cable'),
    ('Overhead triceps extension',    'Overhead Triceps Extension',    5, 'kracht', 'cable'),
    -- Buikspieren
    ('Crunches',        'Crunches',        7, 'kracht', 'bodyweight'),
    ('Sit-ups',         'Sit-ups',         7, 'kracht', 'bodyweight'),
    ('Plank',           'Plank',           7, 'kracht', 'bodyweight'),
    ('Leg raises',      'Leg Raises',      7, 'kracht', 'bodyweight'),
    ('Russian twists',  'Russian Twists',  7, 'kracht', 'bodyweight'),
    -- Quadriceps
    ('Squats',                 'Squats',                  8, 'kracht', 'barbell'),
    ('Front squats',           'Front Squats',            8, 'kracht', 'barbell'),
    ('Leg press',              'Leg Press',               8, 'kracht', 'machine'),
    ('Lunges',                 'Lunges',                  8, 'kracht', 'bodyweight'),
    ('Leg extension',          'Leg Extension',           8, 'kracht', 'machine'),
    ('Bulgarian split squat',  'Bulgarian Split Squat',   8, 'kracht', 'dumbbell'),
    -- Hamstrings
    ('Romanian deadlift',  'Romanian Deadlift',  9, 'kracht', 'barbell'),
    ('Leg curl',           'Leg Curl',           9, 'kracht', 'machine'),
    ('Nordic curls',       'Nordic Curls',       9, 'kracht', 'bodyweight'),
    -- Bilspieren
    ('Hip thrust',      'Hip Thrust',       10, 'kracht', 'barbell'),
    ('Glute kickback',  'Glute Kickback',   10, 'kracht', 'cable'),
    -- Kuiten
    ('Calf raises staand',   'Standing Calf Raises',  11, 'kracht', 'machine'),
    ('Calf raises zittend',  'Seated Calf Raises',    11, 'kracht', 'machine'),
    -- Cardio
    ('Hardlopen',    'Running',        13, 'cardio', 'cardio'),
    ('Fietsen',      'Cycling',        13, 'cardio', 'cardio'),
    ('Roeimachine',  'Rowing Machine', 13, 'cardio', 'cardio'),
    ('Crosstrainer', 'Elliptical',     13, 'cardio', 'cardio'),
    ('Springtouw',   'Jump Rope',      13, 'cardio', 'cardio');

CREATE TABLE IF NOT EXISTS workouts (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(200),
    date        DATE     NOT NULL,
    start_time  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time    DATETIME,
    notes       TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS workout_exercises (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    workout_id   INT NOT NULL,
    exercise_id  INT,
    custom_name  VARCHAR(200),
    order_index  INT NOT NULL DEFAULT 0,
    notes        TEXT,
    FOREIGN KEY (workout_id)  REFERENCES workouts(id)  ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sets (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    workout_exercise_id  INT NOT NULL,
    set_number           INT NOT NULL,
    weight_kg            DECIMAL(6,2),
    reps                 INT,
    duration_seconds     INT,
    distance_km          DECIMAL(8,3),
    rpe                  TINYINT,
    is_warmup            TINYINT(1) NOT NULL DEFAULT 0,
    notes                VARCHAR(255),
    FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
) ENGINE=InnoDB;
