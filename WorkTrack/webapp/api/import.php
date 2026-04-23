<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('POST vereist', 405);

$body = json_decode(file_get_contents('php://input'), true);
$items = $body['exercises'] ?? [];
if (!is_array($items) || empty($items)) jsonError('Geen oefeningen ontvangen');

$pdo = getDB();

// Load all muscle groups into a lookup: name_nl → id
$stmt   = $pdo->query('SELECT id, name_nl FROM muscle_groups');
$groups = [];
foreach ($stmt->fetchAll() as $row) {
    $groups[mb_strtolower($row['name_nl'])] = (int)$row['id'];
}

// Load existing exercises (by name_nl, lowercase) to detect duplicates
$stmt    = $pdo->query('SELECT LOWER(name_nl) AS nl FROM exercises');
$existing = [];
foreach ($stmt->fetchAll() as $row) {
    $existing[$row['nl']] = true;
}

$allowedCats  = ['kracht', 'cardio', 'flexibiliteit', 'overig'];
$allowedEquip = ['barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'kettlebell', 'bands', 'cardio', 'overig'];

$inserted  = 0;
$skipped   = 0;
$errors    = [];

$stmt = $pdo->prepare('
    INSERT INTO exercises (name_nl, name_en, muscle_group_id, category, equipment, is_custom)
    VALUES (?, ?, ?, ?, ?, 0)
');

foreach ($items as $i => $item) {
    $namNl = trim($item['name_nl'] ?? '');
    $namEn = trim($item['name_en'] ?? '') ?: null;
    $grpNm = mb_strtolower(trim($item['spiergroep'] ?? ''));
    $cat   = in_array($item['categorie'] ?? '', $allowedCats)  ? $item['categorie'] : 'kracht';
    $equip = in_array($item['materiaal'] ?? '', $allowedEquip) ? $item['materiaal'] : 'overig';

    if ($namNl === '') {
        $errors[] = "Rij $i: naam ontbreekt";
        continue;
    }

    if (isset($existing[mb_strtolower($namNl)])) {
        $skipped++;
        continue;
    }

    $groupId = $groups[$grpNm] ?? null;

    try {
        $stmt->execute([$namNl, $namEn, $groupId, $cat, $equip]);
        $inserted++;
        $existing[mb_strtolower($namNl)] = true;
    } catch (PDOException $e) {
        $errors[] = "Rij $i ($namNl): " . $e->getMessage();
    }
}

jsonResponse([
    'inserted' => $inserted,
    'skipped'  => $skipped,
    'errors'   => $errors,
]);
