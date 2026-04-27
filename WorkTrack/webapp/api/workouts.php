<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? ($_POST['action'] ?? '');
$pdo    = getDB();

$body = [];
if (in_array($method, ['POST', 'PUT', 'PATCH'])) {
    $raw = file_get_contents('php://input');
    if ($raw) {
        $body = json_decode($raw, true) ?? [];
    } else {
        $body = $_POST;
    }
    $action = $action ?: ($body['action'] ?? '');
}

switch ($action) {

    case 'list':
        $limit  = min((int)($_GET['limit'] ?? 20), 100);
        $offset = max((int)($_GET['offset'] ?? 0), 0);
        $user   = getAuthUser();
        // Authenticated: show only that user's workouts.
        // Unauthenticated (web UI): show only ownerless workouts.
        $stmt = $pdo->prepare('
            SELECT w.*,
                   COUNT(DISTINCT we.id)                           AS exercise_count,
                   COUNT(s.id)                                     AS set_count,
                   COALESCE(SUM(s.weight_kg * s.reps), 0)          AS total_volume_kg,
                   TIMESTAMPDIFF(MINUTE, w.start_time, w.end_time) AS duration_min
            FROM workouts w
            LEFT JOIN workout_exercises we ON we.workout_id = w.id
            LEFT JOIN sets s ON s.workout_exercise_id = we.id AND s.is_warmup = 0
            WHERE (? IS NOT NULL AND w.user_id = ?) OR (? IS NULL AND w.user_id IS NULL)
            GROUP BY w.id
            ORDER BY w.date DESC, w.start_time DESC
            LIMIT ? OFFSET ?
        ');
        $uid = $user ? (int)$user['id'] : null;
        $stmt->execute([$uid, $uid, $uid, $limit, $offset]);
        jsonResponse($stmt->fetchAll());
        break;

    case 'get':
        $id = (int)($_GET['id'] ?? 0);
        if (!$id) jsonError('id is required');
        assertWorkoutAccess($pdo, $id);
        $workout = getWorkoutWithExercises($id);
        if (!$workout) jsonError('Workout not found', 404);
        jsonResponse($workout);
        break;

    case 'create':
        requireCsrfOrBearer();
        $date = $body['date'] ?? date('Y-m-d');
        // Validate date format to prevent unexpected behaviour
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || !checkdate(
            (int)substr($date, 5, 2), (int)substr($date, 8, 2), (int)substr($date, 0, 4)
        )) {
            $date = date('Y-m-d');
        }
        $name   = trim(substr($body['name'] ?? '', 0, 200));
        $user   = getAuthUser();
        $userId = $user ? (int)$user['id'] : null;
        $stmt   = $pdo->prepare('INSERT INTO workouts (user_id, name, date, start_time) VALUES (?, ?, ?, NOW())');
        $stmt->execute([$userId, $name ?: null, $date]);
        $id   = (int)$pdo->lastInsertId();
        $stmt = $pdo->prepare('SELECT * FROM workouts WHERE id = ?');
        $stmt->execute([$id]);
        jsonResponse($stmt->fetch());
        break;

    case 'update':
        requireCsrfOrBearer();
        $id = (int)($body['id'] ?? 0);
        if (!$id) jsonError('id is required');
        assertWorkoutAccess($pdo, $id);
        $fields = [];
        $params = [];
        if (array_key_exists('name', $body))  { $fields[] = 'name = ?';  $params[] = trim(substr($body['name']  ?? '', 0, 200)) ?: null; }
        if (array_key_exists('notes', $body)) { $fields[] = 'notes = ?'; $params[] = trim(substr($body['notes'] ?? '', 0, 2000)) ?: null; }
        if (!$fields) jsonError('Nothing to update');
        $params[] = $id;
        $pdo->prepare('UPDATE workouts SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        jsonResponse(['ok' => true]);
        break;

    case 'finish':
        requireCsrfOrBearer();
        $id = (int)($body['id'] ?? 0);
        if (!$id) jsonError('id is required');
        assertWorkoutAccess($pdo, $id);
        $pdo->prepare('UPDATE workouts SET end_time = NOW() WHERE id = ? AND end_time IS NULL')->execute([$id]);
        jsonResponse(['ok' => true]);
        break;

    case 'delete':
        requireCsrfOrBearer();
        $id = (int)($body['id'] ?? 0);
        if (!$id) jsonError('id is required');
        assertWorkoutAccess($pdo, $id);
        $pdo->prepare('DELETE FROM workouts WHERE id = ?')->execute([$id]);
        jsonResponse(['ok' => true]);
        break;

    case 'add_exercise':
        requireCsrfOrBearer();
        $workoutId  = (int)($body['workout_id'] ?? 0);
        $exerciseId = (int)($body['exercise_id'] ?? 0) ?: null;
        $customName = trim(substr($body['custom_name'] ?? '', 0, 200));
        if (!$workoutId) jsonError('workout_id is required');
        if (!$exerciseId && $customName === '') jsonError('exercise_id or custom_name is required');
        assertWorkoutAccess($pdo, $workoutId);

        $stmt = $pdo->prepare('SELECT MAX(order_index) FROM workout_exercises WHERE workout_id = ?');
        $stmt->execute([$workoutId]);
        $next = (int)($stmt->fetchColumn() ?? -1) + 1;

        $stmt = $pdo->prepare('INSERT INTO workout_exercises (workout_id, exercise_id, custom_name, order_index) VALUES (?, ?, ?, ?)');
        $stmt->execute([$workoutId, $exerciseId, $customName ?: null, $next]);
        $weId = (int)$pdo->lastInsertId();

        $stmt = $pdo->prepare('
            SELECT we.id, we.order_index,
                   COALESCE(we.custom_name, e.name_en, e.name_nl) AS name,
                   e.category, e.equipment,
                   mg.name_en AS muscle_group
            FROM workout_exercises we
            LEFT JOIN exercises e      ON e.id  = we.exercise_id
            LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
            WHERE we.id = ?
        ');
        $stmt->execute([$weId]);
        jsonResponse($stmt->fetch());
        break;

    case 'remove_exercise':
        requireCsrfOrBearer();
        $weId = (int)($body['we_id'] ?? 0);
        if (!$weId) jsonError('we_id is required');
        // Verify ownership via the parent workout
        $stmt = $pdo->prepare('SELECT workout_id FROM workout_exercises WHERE id = ?');
        $stmt->execute([$weId]);
        $wId = (int)($stmt->fetchColumn() ?: 0);
        if (!$wId) jsonError('Exercise not found', 404);
        assertWorkoutAccess($pdo, $wId);
        $pdo->prepare('DELETE FROM workout_exercises WHERE id = ?')->execute([$weId]);
        jsonResponse(['ok' => true]);
        break;

    case 'save_set':
        requireCsrfOrBearer();
        $weId      = (int)($body['we_id'] ?? 0);
        $setNumber = (int)($body['set_number'] ?? 0);
        if (!$weId || !$setNumber) jsonError('we_id and set_number are required');
        // Verify ownership via workout_exercises → workouts
        $stmt = $pdo->prepare('SELECT workout_id FROM workout_exercises WHERE id = ?');
        $stmt->execute([$weId]);
        $wId = (int)($stmt->fetchColumn() ?: 0);
        if (!$wId) jsonError('Exercise not found', 404);
        assertWorkoutAccess($pdo, $wId);

        $weightKg = isset($body['weight_kg'])        && $body['weight_kg']        !== '' ? (float)$body['weight_kg']        : null;
        $reps     = isset($body['reps'])             && $body['reps']             !== '' ? (int)$body['reps']                : null;
        $duration = isset($body['duration_seconds']) && $body['duration_seconds'] !== '' ? (int)$body['duration_seconds']   : null;
        $distance = isset($body['distance_km'])      && $body['distance_km']      !== '' ? (float)$body['distance_km']      : null;
        $rpe      = isset($body['rpe'])              && $body['rpe']              !== '' ? (int)$body['rpe']                : null;
        $warmup   = (int)(bool)($body['is_warmup'] ?? false);

        // Clamp RPE
        if ($rpe !== null) $rpe = max(1, min(10, $rpe));

        $stmt = $pdo->prepare('SELECT id FROM sets WHERE workout_exercise_id = ? AND set_number = ?');
        $stmt->execute([$weId, $setNumber]);
        $existing = $stmt->fetchColumn();

        if ($existing) {
            $pdo->prepare('
                UPDATE sets
                SET weight_kg = ?, reps = ?, duration_seconds = ?, distance_km = ?,
                    rpe = ?, is_warmup = ?
                WHERE id = ?
            ')->execute([$weightKg, $reps, $duration, $distance, $rpe, $warmup, $existing]);
            jsonResponse(['id' => (int)$existing]);
        } else {
            $pdo->prepare('
                INSERT INTO sets (workout_exercise_id, set_number, weight_kg, reps, duration_seconds, distance_km, rpe, is_warmup)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ')->execute([$weId, $setNumber, $weightKg, $reps, $duration, $distance, $rpe, $warmup]);
            jsonResponse(['id' => (int)$pdo->lastInsertId()]);
        }
        break;

    case 'remove_set':
        requireCsrfOrBearer();
        $setId  = (int)($body['set_id']     ?? 0);
        $weId   = (int)($body['we_id']      ?? 0);
        $setNum = (int)($body['set_number'] ?? 0);
        // Resolve workout ownership
        $resolveWeId = $weId ?: (function() use ($pdo, $setId) {
            if (!$setId) return 0;
            $s = $pdo->prepare('SELECT workout_exercise_id FROM sets WHERE id = ?');
            $s->execute([$setId]);
            return (int)($s->fetchColumn() ?: 0);
        })();
        if ($resolveWeId) {
            $stmt = $pdo->prepare('SELECT workout_id FROM workout_exercises WHERE id = ?');
            $stmt->execute([$resolveWeId]);
            $wId = (int)($stmt->fetchColumn() ?: 0);
            if ($wId) assertWorkoutAccess($pdo, $wId);
        }
        if ($setId) {
            $pdo->prepare('DELETE FROM sets WHERE id = ?')->execute([$setId]);
        } elseif ($weId && $setNum) {
            $pdo->prepare('DELETE FROM sets WHERE workout_exercise_id = ? AND set_number = ?')->execute([$weId, $setNum]);
        } else {
            jsonError('set_id or we_id + set_number is required');
        }
        jsonResponse(['ok' => true]);
        break;

    default:
        // Do not echo back unknown action values — suppresses information disclosure
        jsonError('Unknown action', 404);
}
