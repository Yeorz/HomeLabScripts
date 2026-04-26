<?php
/**
 * Mobile-compatible API endpoint.
 * Handles the simple {type, duration, calories} workout format used by
 * the iOS app, React Native app, and Apple Watch, plus analytics endpoints.
 */
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';

setCORSHeaders();
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? 'workouts';
$pdo    = getDB();

$body = [];
if (in_array($method, ['POST', 'PUT'])) {
    $raw  = file_get_contents('php://input');
    $body = $raw ? (json_decode($raw, true) ?? $_POST) : $_POST;
}

switch ($action) {

    // ── POST /workouts  ──────────────────────────────────────────────────
    // Accepts: { type, duration, calories, segments? }
    // Returns: { id, ok }
    case 'workouts':
        if ($method !== 'POST') jsonError('POST required', 405);

        $user = requireAuth();

        $type     = trim($body['type']     ?? 'Strength');
        $duration = (int)($body['duration'] ?? 0);
        $calories = (int)($body['calories'] ?? 0);
        $segments = $body['segments'] ?? null; // optional from Watch

        $allowedTypes = ['Strength', 'Cardio', 'Flexibility', 'HIIT', 'Yoga', 'Rowing', 'Core', 'Stretch'];
        if (!in_array($type, $allowedTypes, true)) $type = 'Strength';
        if ($duration < 0 || $duration > 86400) jsonError('Invalid duration');
        if ($calories < 0 || $calories > 9999)  jsonError('Invalid calories');

        // Build workout record
        $date      = date('Y-m-d');
        $startTime = date('Y-m-d H:i:s', time() - $duration);
        $endTime   = date('Y-m-d H:i:s');
        $notes     = null;

        if ($segments && is_array($segments)) {
            // Store segment summary in notes
            $lines = array_map(function($s) {
                $label = htmlspecialchars($s['label'] ?? 'Unknown', ENT_QUOTES, 'UTF-8');
                $sec   = round($s['duration'] ?? 0);
                $conf  = round(($s['confidence'] ?? 0) * 100);
                return "$label: {$sec}s ({$conf}% confidence)";
            }, $segments);
            $notes = implode(', ', $lines);
        }

        $stmt = $pdo->prepare('
            INSERT INTO workouts
                (user_id, name, date, start_time, end_time, workout_type, calories, duration_seconds, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ');
        $stmt->execute([
            $user['id'],
            $type,
            $date,
            $startTime,
            $endTime,
            $type,
            $calories ?: null,
            $duration ?: null,
            $notes,
        ]);

        jsonResponse(['id' => (int)$pdo->lastInsertId(), 'ok' => true]);
        break;

    // ── GET /analytics/summary ───────────────────────────────────────────
    case 'summary':
        $user = requireAuth();
        $stmt = $pdo->prepare('
            SELECT
                COALESCE(workout_type, "Strength")  AS type,
                COUNT(*)                            AS sessions,
                COALESCE(SUM(duration_seconds)/60, 0) AS total_minutes,
                COALESCE(SUM(calories), 0)          AS calories
            FROM workouts
            WHERE user_id = ?
            GROUP BY workout_type
            ORDER BY sessions DESC
        ');
        $stmt->execute([$user['id']]);
        jsonResponse($stmt->fetchAll());
        break;

    // ── GET /analytics/trends  ───────────────────────────────────────────
    case 'trends':
        $user = requireAuth();
        $stmt = $pdo->prepare('
            SELECT
                date                                    AS day,
                COALESCE(SUM(calories), 0)              AS calories,
                COALESCE(SUM(duration_seconds) / 60, 0) AS minutes
            FROM workouts
            WHERE user_id = ?
              AND date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
            GROUP BY date
            ORDER BY date DESC
            LIMIT 30
        ');
        $stmt->execute([$user['id']]);
        jsonResponse($stmt->fetchAll());
        break;

    // ── GET /public/:userId ──────────────────────────────────────────────
    case 'public':
        $userId = (int)($_GET['userId'] ?? $_GET['user_id'] ?? 0);
        if (!$userId) jsonError('Invalid user ID', 400);

        $stmt = $pdo->prepare('SELECT id FROM users WHERE id = ?');
        $stmt->execute([$userId]);
        if (!$stmt->fetchColumn()) jsonError('User not found', 404);

        $stmt = $pdo->prepare('
            SELECT date AS day, COALESCE(SUM(calories), 0) AS calories
            FROM workouts
            WHERE user_id = ?
              AND date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
            GROUP BY date
            ORDER BY date DESC
        ');
        $stmt->execute([$userId]);
        jsonResponse(['workouts' => $stmt->fetchAll()]);
        break;

    default:
        jsonError('Unknown action', 404);
}
