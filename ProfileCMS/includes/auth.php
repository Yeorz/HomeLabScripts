<?php
require_once __DIR__ . '/db.php';

function session_start_once(): void {
    if (session_status() === PHP_SESSION_NONE) {
        session_name('profilecms_session');
        session_start();
    }
}

function is_logged_in(): bool {
    session_start_once();
    return !empty($_SESSION['admin_user_id']);
}

function require_login(): void {
    if (!is_logged_in()) {
        header('Location: /admin/login.php');
        exit;
    }
}

function login(string $username, string $password): bool {
    $stmt = db()->prepare('SELECT id, password_hash FROM users WHERE username = ?');
    $stmt->execute([$username]);
    $user = $stmt->fetch();
    if ($user && password_verify($password, $user['password_hash'])) {
        session_start_once();
        session_regenerate_id(true);
        $_SESSION['admin_user_id'] = $user['id'];
        $_SESSION['admin_username'] = $username;
        return true;
    }
    return false;
}

function logout(): void {
    session_start_once();
    $_SESSION = [];
    session_destroy();
}

function csrf_token(): string {
    session_start_once();
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function verify_csrf(): void {
    $token = $_POST['csrf_token'] ?? '';
    if (!hash_equals(csrf_token(), $token)) {
        http_response_code(403);
        die('Invalid CSRF token.');
    }
}
