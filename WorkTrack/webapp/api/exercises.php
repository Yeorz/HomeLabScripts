<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$action = $_GET['action'] ?? 'list';
$pdo    = getDB();

switch ($action) {
    case 'search':
        $q    = trim($_GET['q'] ?? '');
        $group = (int)($_GET['group'] ?? 0);

        $params = [];
        $where  = [];

        if ($q !== '') {
            $like     = '%' . str_replace(['%','_'], ['\\%','\\_'], $q) . '%';
            $where[]  = '(e.name_nl LIKE ? OR e.name_en LIKE ?)';
            $params[] = $like;
            $params[] = $like;
        }
        if ($group > 0) {
            $where[]  = 'e.muscle_group_id = ?';
            $params[] = $group;
        }

        $sql  = '
            SELECT e.id, e.name_nl, e.name_en, e.category, e.equipment, e.is_custom,
                   mg.name_nl AS muscle_group
            FROM exercises e
            LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
        ';
        if ($where) $sql .= 'WHERE ' . implode(' AND ', $where) . ' ';
        $sql .= 'ORDER BY mg.name_nl, e.name_nl LIMIT 60';

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        jsonResponse($stmt->fetchAll());
        break;

    case 'list':
        $stmt = $pdo->query('
            SELECT e.id, e.name_nl, e.name_en, e.category, e.equipment, e.is_custom,
                   e.muscle_group_id, mg.name_nl AS muscle_group
            FROM exercises e
            LEFT JOIN muscle_groups mg ON mg.id = e.muscle_group_id
            ORDER BY mg.name_nl, e.name_nl
        ');
        jsonResponse($stmt->fetchAll());
        break;

    case 'groups':
        $stmt = $pdo->query('SELECT * FROM muscle_groups ORDER BY name_nl');
        jsonResponse($stmt->fetchAll());
        break;

    case 'create':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('POST vereist', 405);
        $body = json_decode(file_get_contents('php://input'), true);
        $name = trim($body['name_nl'] ?? '');
        if ($name === '') jsonError('Naam is verplicht');

        $stmt = $pdo->prepare('
            INSERT INTO exercises (name_nl, name_en, muscle_group_id, category, equipment, is_custom)
            VALUES (?, ?, ?, ?, ?, 1)
        ');
        $stmt->execute([
            $name,
            trim($body['name_en'] ?? '') ?: null,
            (int)($body['muscle_group_id'] ?? 0) ?: null,
            in_array($body['category'] ?? '', ['kracht','cardio','flexibiliteit','overig']) ? $body['category'] : 'kracht',
            in_array($body['equipment'] ?? '', ['barbell','dumbbell','machine','cable','bodyweight','kettlebell','bands','cardio','overig']) ? $body['equipment'] : 'overig',
        ]);
        jsonResponse(['id' => (int)$pdo->lastInsertId(), 'name_nl' => $name]);
        break;

    default:
        jsonError('Onbekende actie', 404);
}
