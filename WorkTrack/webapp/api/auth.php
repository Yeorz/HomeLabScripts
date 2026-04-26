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

// Parse JSON body
$body = [];
if (in_array($method, ['POST', 'PUT'])) {
    $raw  = file_get_contents('php://input');
    $body = $raw ? (json_decode($raw, true) ?? $_POST) : $_POST;
}

switch ($action) {

    // ── CSRF token ──────────────────────────────────────────────────────
    case 'csrf-token':
        jsonResponse(['csrfToken' => csrfGenerate()]);
        break;

    // ── Register ────────────────────────────────────────────────────────
    case 'register':
        if ($method !== 'POST') jsonError('POST required', 405);

        $email    = trim($body['email'] ?? '');
        $password = $body['password'] ?? '';

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            jsonError('Invalid email address');
        }
        if (strlen($password) < 8) {
            jsonError('Password must be at least 8 characters');
        }

        // Check duplicate
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
        $stmt->execute([$email]);
        if ($stmt->fetchColumn()) {
            jsonError('Email already registered', 409);
        }

        $hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        $stmt = $pdo->prepare('INSERT INTO users (email, password) VALUES (?, ?)');
        $stmt->execute([$email, $hash]);
        $userId = (int)$pdo->lastInsertId();

        $token = issueToken($userId);
        setcookie('token', $token, [
            'expires'  => time() + 86400,
            'path'     => '/',
            'httponly' => true,
            'samesite' => 'Lax',
        ]);

        jsonResponse([
            'token' => $token,
            'user'  => ['id' => $userId, 'email' => $email],
        ]);
        break;

    // ── Login ────────────────────────────────────────────────────────────
    case 'login':
        if ($method !== 'POST') jsonError('POST required', 405);

        $email    = trim($body['email'] ?? '');
        $password = $body['password'] ?? '';

        $stmt = $pdo->prepare('SELECT id, email, password FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password'])) {
            jsonError('Invalid credentials', 401);
        }

        $token = issueToken((int)$user['id']);
        setcookie('token', $token, [
            'expires'  => time() + 86400,
            'path'     => '/',
            'httponly' => true,
            'samesite' => 'Lax',
        ]);

        jsonResponse([
            'token' => $token,
            'user'  => ['id' => (int)$user['id'], 'email' => $user['email']],
        ]);
        break;

    // ── Session ──────────────────────────────────────────────────────────
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

    // ── Logout ───────────────────────────────────────────────────────────
    case 'logout':
        setcookie('token', '', ['expires' => time() - 3600, 'path' => '/', 'httponly' => true]);
        jsonResponse(['ok' => true]);
        break;

    default:
        jsonError('Unknown action', 404);
}
