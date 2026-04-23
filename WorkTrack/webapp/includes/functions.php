<?php
function getSettings(): array {
    $pdo  = getDB();
    $stmt = $pdo->query('SELECT * FROM settings WHERE id = 1');
    return $stmt->fetch() ?: ['unit_system' => 'metric', 'theme' => 'dark'];
}

function updateSettings(string $unitSystem, string $theme): void {
    $pdo  = getDB();
    $stmt = $pdo->prepare('UPDATE settings SET unit_system = ?, theme = ? WHERE id = 1');
    $stmt->execute([$unitSystem, $theme]);
}

function formatWeight(float $kg, string $unitSystem): string {
    if ($unitSystem === 'imperial') {
        $lbs = $kg * 2.20462;
        return number_format($lbs, $lbs == round($lbs) ? 0 : 1) . ' lbs';
    }
    return ($kg == floor($kg) ? (int)$kg : $kg) . ' kg';
}

function formatDistance(float $km, string $unitSystem): string {
    if ($unitSystem === 'imperial') {
        return number_format($km * 0.621371, 2) . ' mi';
    }
    return number_format($km, 2) . ' km';
}

function formatDuration(int $seconds): string {
    if ($seconds >= 3600) {
        return sprintf('%d:%02d:%02d', intdiv($seconds, 3600), intdiv($seconds % 3600, 60), $seconds % 60);
    }
    return sprintf('%d:%02d', intdiv($seconds, 60), $seconds % 60);
}

function formatDate(string $date, bool $withDay = true): string {
    static $months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'];
    static $days   = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    $ts = strtotime($date);
    $d  = (int) date('j', $ts);
    $m  = $months[(int) date('n', $ts)];
    $y  = date('Y', $ts);
    if ($withDay) {
        return $days[(int) date('w', $ts)] . " $d $m $y";
    }
    return "$d $m $y";
}

function h(string $str): string {
    return htmlspecialchars($str, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function jsonResponse(mixed $data, int $status = 200): never {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function jsonError(string $message, int $status = 400): never {
    jsonResponse(['error' => $message], $status);
}

function getWorkoutStats(int $workoutId): array {
    $pdo  = getDB();
    $stmt = $pdo->prepare('
        SELECT
            COUNT(DISTINCT we.id)                              AS exercise_count,
            COUNT(s.id)                                        AS set_count,
            COALESCE(SUM(s.weight_kg * s.reps), 0)            AS total_volume_kg,
            COALESCE(SUM(s.duration_seconds), 0)               AS total_duration_s
        FROM workout_exercises we
        LEFT JOIN sets s ON s.workout_exercise_id = we.id AND s.is_warmup = 0
        WHERE we.workout_id = ?
    ');
    $stmt->execute([$workoutId]);
    return $stmt->fetch();
}

function getWorkoutWithExercises(int $workoutId): ?array {
    $pdo  = getDB();
    $stmt = $pdo->prepare('SELECT * FROM workouts WHERE id = ?');
    $stmt->execute([$workoutId]);
    $workout = $stmt->fetch();
    if (!$workout) return null;

    $stmt = $pdo->prepare('
        SELECT we.id, we.order_index, we.notes AS we_notes,
               e.id AS exercise_id,
               COALESCE(we.custom_name, e.name_en, e.name_nl) AS name,
               e.category, e.equipment,
               mg.name_en AS muscle_group
        FROM workout_exercises we
        LEFT JOIN exercises e      ON e.id  = we.exercise_id
        LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
        WHERE we.workout_id = ?
        ORDER BY we.order_index, we.id
    ');
    $stmt->execute([$workoutId]);
    $wes = $stmt->fetchAll();

    foreach ($wes as &$we) {
        $s = $pdo->prepare('SELECT * FROM sets WHERE workout_exercise_id = ? ORDER BY set_number');
        $s->execute([$we['id']]);
        $we['sets'] = $s->fetchAll();
    }

    $workout['exercises'] = $wes;
    return $workout;
}
