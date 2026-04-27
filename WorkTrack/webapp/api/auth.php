<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';

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

        $email    = trim($body['email'] ?? '');
        $password = $body['password'] ?? '';

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) jsonError('Invalid email address');
        if (strlen($email) > 254) jsonError('Invalid email address');
        if (strlen($password) < 10) jsonError('Password must be at least 10 characters');
        if (strlen($password) > 1024) jsonError('Password too long');

        $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
        $stmt->execute([$email]);
        if ($stmt->fetchColumn()) jsonError('Email already registered', 409);

        $hash   = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        $stmt   = $pdo->prepare('INSERT INTO users (email, password) VALUES (?, ?)');
        $stmt->execute([$email, $hash]);
        $userId = (int)$pdo->lastInsertId();

        $token = issueToken($userId);
        setAuthCookie($token);
        jsonResponse(['token' => $token, 'user' => ['id' => $userId, 'email' => $email]]);
        break;

    case 'login':
        if ($method !== 'POST') jsonError('POST required', 405);

        $email    = trim($body['email'] ?? '');
        $password = $body['password'] ?? '';

        if (strlen($email) > 254 || strlen($password) > 1024) {
            // Avoid bcrypt with very long passwords; respond with generic error
            jsonError('Invalid credentials', 401);
        }

        $stmt = $pdo->prepare('SELECT id, email, password FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        // Always run password_verify even on no-result to prevent timing-based enumeration
        $dummyHash = '$2y$12$invalidhashfortimingnormalization000000000000000000000';
        $hash      = $user['password'] ?? $dummyHash;
        $valid     = password_verify($password, $hash);

        if (!$user || !$valid) {
            jsonError('Invalid credentials', 401);
        }

        $token = issueToken((int)$user['id']);
        setAuthCookie($token);
        jsonResponse(['token' => $token, 'user' => ['id' => (int)$user['id'], 'email' => $user['email']]]);
        break;

    case 'session':
        $payload = getAuthUser();
        if (!$payload) {
            jsonResponse(['user' => null], 401);
        }
        $stmt = $pdo->prepare('SELECT id, email FROM users WHERE id = ?');
        $stmt->execute([$payload['id']]);
        $user = $stmt->fetch();
        jsonResponse(['user' => $user ?: null]);
        break;

    case 'logout':
        clearAuthCookie();
        jsonResponse(['ok' => true]);
        break;

    default:
        jsonError('Unknown action', 404);
}
