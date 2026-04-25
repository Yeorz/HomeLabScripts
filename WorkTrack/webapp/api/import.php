<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('POST required', 405);

$body  = json_decode(file_get_contents('php://input'), true);
$items = $body['exercises'] ?? [];
if (!is_array($items) || empty($items)) jsonError('No exercises received');

$pdo = getDB();

// Build lookup: both name_en and name_nl → id (for flexible matching)
$stmt   = $pdo->query('SELECT id, name_nl, name_en FROM muscle_groups');
$groups = [];
foreach ($stmt->fetchAll() as $row) {
    if ($row['name_nl']) $groups[mb_strtolower($row['name_nl'])] = (int)$row['id'];
    if ($row['name_en']) $groups[mb_strtolower($row['name_en'])] = (int)$row['id'];
}

// Existing exercises by name_en and name_nl (lowercase) to detect duplicates
$stmt     = $pdo->query('SELECT LOWER(name_nl) AS nl, LOWER(COALESCE(name_en, \'\')) AS en FROM exercises');
$existing = [];
foreach ($stmt->fetchAll() as $row) {
    if ($row['nl']) $existing[$row['nl']] = true;
    if ($row['en']) $existing[$row['en']] = true;
}

$allowedCats  = ['kracht', 'cardio', 'flexibiliteit', 'overig'];
$allowedEquip = ['barbell', 'dumbbell', 'machine', 'cable', 'bodyweight', 'kettlebell', 'bands', 'cardio', 'overig'];

$inserted = 0;
$skipped  = 0;
$errors   = [];

$stmt = $pdo->prepare('
    INSERT INTO exercises (name_nl, name_en, muscle_group_id, category, equipment, is_custom)
    VALUES (?, ?, ?, ?, ?, 0)
');

foreach ($items as $i => $item) {
    $nameEn = trim($item['name_en'] ?? $item['name_nl'] ?? '');
    $nameNl = trim($item['name_nl'] ?? $nameEn);
    $grpKey = mb_strtolower(trim($item['spiergroep'] ?? $item['muscle_group'] ?? ''));
    $cat    = in_array($item['categorie'] ?? $item['category'] ?? '', $allowedCats)  ? ($item['categorie'] ?? $item['category']) : 'kracht';
    $equip  = in_array($item['materiaal'] ?? $item['equipment'] ?? '', $allowedEquip) ? ($item['materiaal'] ?? $item['equipment']) : 'overig';

    if ($nameEn === '' && $nameNl === '') {
        $errors[] = "Row $i: name is missing";
        continue;
    }

    $key = mb_strtolower($nameEn ?: $nameNl);
    if (isset($existing[$key]) || isset($existing[mb_strtolower($nameNl)])) {
        $skipped++;
        continue;
    }

    $groupId = $groups[$grpKey] ?? null;

    try {
        $stmt->execute([$nameNl ?: $nameEn, $nameEn ?: null, $groupId, $cat, $equip]);
        $inserted++;
        $existing[$key] = true;
    } catch (PDOException $e) {
        $errors[] = "Row $i ($nameEn): " . $e->getMessage();
    }
}

jsonResponse([
    'inserted' => $inserted,
    'skipped'  => $skipped,
    'errors'   => $errors,
]);
