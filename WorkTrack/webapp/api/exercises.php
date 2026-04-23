<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$action = $_GET['action'] ?? 'list';
$pdo    = getDB();

switch ($action) {
    case 'search':
        $q     = trim($_GET['q'] ?? '');
        $group = (int)($_GET['group'] ?? 0);

        $params = [];
        $where  = [];

        if ($q !== '') {
            $like     = '%' . str_replace(['%', '_'], ['\\%', '\\_'], $q) . '%';
            $where[]  = '(e.name_en LIKE ? OR e.name_nl LIKE ?)';
            $params[] = $like;
            $params[] = $like;
        }
        if ($group > 0) {
            $where[]  = 'e.muscle_group_id = ?';
            $params[] = $group;
        }

        $sql = '
            SELECT e.id,
                   COALESCE(e.name_en, e.name_nl) AS name,
                   e.name_en, e.name_nl,
                   e.category, e.equipment, e.is_custom,
                   mg.name_en AS muscle_group
            FROM exercises e
            LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
        ';
        if ($where) $sql .= 'WHERE ' . implode(' AND ', $where) . ' ';
        $sql .= 'ORDER BY mg.name_en, e.name_en LIMIT 60';

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        jsonResponse($stmt->fetchAll());
        break;

    case 'list':
        $stmt = $pdo->query('
            SELECT e.id,
                   COALESCE(e.name_en, e.name_nl) AS name,
                   e.name_en, e.name_nl,
                   e.category, e.equipment, e.is_custom,
                   e.muscle_group_id,
                   mg.name_en AS muscle_group
            FROM exercises e
            LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
            ORDER BY mg.name_en, e.name_en
        ');
        jsonResponse($stmt->fetchAll());
        break;

    case 'groups':
        $stmt = $pdo->query('SELECT * FROM muscle_groups ORDER BY name_en');
        jsonResponse($stmt->fetchAll());
        break;

    case 'create':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('POST required', 405);
        $body = json_decode(file_get_contents('php://input'), true);
        $name = trim($body['name_en'] ?? $body['name_nl'] ?? '');
        if ($name === '') jsonError('Name is required');

        $stmt = $pdo->prepare('
            INSERT INTO exercises (name_nl, name_en, muscle_group_id, category, equipment, is_custom)
            VALUES (?, ?, ?, ?, ?, 1)
        ');
        $stmt->execute([
            trim($body['name_nl'] ?? '') ?: $name,
            $name,
            (int)($body['muscle_group_id'] ?? 0) ?: null,
            in_array($body['category'] ?? '', ['kracht', 'cardio', 'flexibiliteit', 'overig']) ? $body['category'] : 'kracht',
            in_array($body['equipment'] ?? '', ['barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'kettlebell', 'bands', 'cardio', 'overig']) ? $body['equipment'] : 'overig',
        ]);
        jsonResponse(['id' => (int)$pdo->lastInsertId(), 'name' => $name]);
        break;

    default:
        jsonError('Unknown action', 404);
}
