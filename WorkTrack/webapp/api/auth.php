<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/crypto.php';

setCORSHeaders();
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';
$pdo    = getDB();

$body = [];
if (in_array($method, ['POST', 'PUT'])) {
    $raw  = file_get_contents('php://input');
    $body = $raw ? (json_decode($raw, true) ?? $_POST) : $_POST;
}

switch ($action) {

    case 'csrf-token':
        jsonResponse(['csrfToken' => csrfGenerate()]);
        break;

    case 'register':
        if ($method !== 'POST') jsonError('POST required', 405);

        $email    = mb_strtolower(trim($body['email']    ?? ''));
        $password = $body['password'] ?? '';

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) jsonError('Invalid email address');
        if (strlen($email) > 254)   jsonError('Invalid email address');
        if (strlen($password) < 10) jsonError('Password must be at least 10 characters');
        if (strlen($password) > 1024) jsonError('Password too long');

        // Duplicate check via blind index — no plaintext email in the WHERE clause
        $emailHash = searchHash($email);
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email_hash = ?');
        $stmt->execute([$emailHash]);
        if ($stmt->fetchColumn()) jsonError('Email already registered', 409);

        $hash   = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        $stmt   = $pdo->prepare('INSERT INTO users (email, email_hash, password) VALUES (?, ?, ?)');
        $stmt->execute([encryptField($email), $emailHash, $hash]);
        $userId = (int)$pdo->lastInsertId();

        $token = issueToken($userId);
        setAuthCookie($token);
        jsonResponse(['token' => $token, 'user' => ['id' => $userId, 'email' => $email]]);
        break;

    case 'login':
        if ($method !== 'POST') jsonError('POST required', 405);

        $email    = mb_strtolower(trim($body['email']    ?? ''));
        $password = $body['password'] ?? '';

        if (strlen($email) > 254 || strlen($password) > 1024) {
            jsonError('Invalid credentials', 401);
        }

        // Lookup via blind index
        $emailHash = searchHash($email);
        $stmt = $pdo->prepare('SELECT id, password FROM users WHERE email_hash = ?');
        $stmt->execute([$emailHash]);
        $user = $stmt->fetch();

        $dummy = '$2y$12$invalidhashfortimingnormalization000000000000000000000';
        $hash  = $user['password'] ?? $dummy;
        $valid = password_verify($password, $hash);

        if (!$user || !$valid) jsonError('Invalid credentials', 401);

        $token = issueToken((int)$user['id']);
        setAuthCookie($token);
        jsonResponse(['token' => $token, 'user' => ['id' => (int)$user['id'], 'email' => $email]]);
        break;

    case 'session':
        $payload = getAuthUser();
        if (!$payload) {
            jsonResponse(['user' => null], 401);
        }
        $stmt = $pdo->prepare('SELECT id, email, name FROM users WHERE id = ?');
        $stmt->execute([$payload['id']]);
        $row = $stmt->fetch();
        if (!$row) jsonResponse(['user' => null], 401);

        jsonResponse(['user' => [
            'id'    => (int)$row['id'],
            'email' => df($row['email']),
            'name'  => df($row['name']),
        ]]);
        break;

    case 'logout':
        clearAuthCookie();
        jsonResponse(['ok' => true]);
        break;

    default:
        jsonError('Unknown action', 404);
}
