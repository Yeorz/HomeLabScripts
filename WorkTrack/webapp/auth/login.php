<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/crypto.php';
require_once dirname(__DIR__) . '/includes/oauth.php';

// Already signed in — go straight to the dashboard
if (getAuthUser()) {
    header('Location: /webapp/');
    exit;
}

$redirect  = safeRedirectUrl($_GET['redirect'] ?? '');
$mode      = $_GET['mode'] ?? 'login';     // 'login' | 'register'
$error     = trim($_GET['error'] ?? '');

// ── Email / password form submission ─────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['email'])) {
    $csrf = $_POST['_csrf'] ?? '';
    if (!csrfVerify($csrf)) {
        $error = 'Session expired. Please try again.';
    } else {
        $email    = trim($_POST['email']    ?? '');
        $password =       $_POST['password'] ?? '';
        $pdo      = getDB();

        if ($mode === 'register') {
            $confirm = $_POST['confirm'] ?? '';
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $error = 'Invalid email address.';
            } elseif (strlen($password) < 10) {
                $error = 'Password must be at least 10 characters.';
            } elseif ($password !== $confirm) {
                $error = 'Passwords do not match.';
            } else {
                $emailHash = searchHash($email);
                $stmt = $pdo->prepare('SELECT id FROM users WHERE email_hash = ?');
                $stmt->execute([$emailHash]);
                if ($stmt->fetchColumn()) {
                    $error = 'An account with this email already exists.';
                } else {
                    $hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
                    $stmt = $pdo->prepare('INSERT INTO users (email, email_hash, password) VALUES (?, ?, ?)');
                    $stmt->execute([encryptField($email), $emailHash, $hash]);
                    $userId = (int)$pdo->lastInsertId();
                    setAuthCookie(issueToken($userId));
                    header('Location: ' . ($redirect ?: '/webapp/'));
                    exit;
                }
            }
        } else {
            // Login
            if (strlen($email) > 254 || strlen($password) > 1024) {
                $error = 'Invalid credentials.';
            } else {
                $stmt = $pdo->prepare('SELECT id, password FROM users WHERE email_hash = ?');
                $stmt->execute([searchHash($email)]);
                $user = $stmt->fetch();
                $dummy = '$2y$12$invalidhashfortimingnormalization000000000000000000000';
                $hash  = $user['password'] ?? $dummy;
                if (!$user || !password_verify($password, $hash)) {
                    $error = 'Invalid email or password.';
                } else {
                    setAuthCookie(issueToken((int)$user['id']));
                    header('Location: ' . ($redirect ?: '/webapp/'));
                    exit;
                }
            }
        }
    }
}

$isRegister  = ($mode === 'register');
$switchMode  = $isRegister ? 'login' : 'register';
$switchLabel = $isRegister ? 'Sign in instead' : 'Create an account';
$title       = $isRegister ? 'Create account' : 'Sign in';

// Build OAuth URLs (only for configured providers)
$googleUrl   = googleEnabled()   ? googleAuthUrl(oauthStateCreate('google',   $redirect)) : null;
$facebookUrl = facebookEnabled() ? facebookAuthUrl(oauthStateCreate('facebook', $redirect)) : null;
$appleUrl    = appleEnabled()    ? appleAuthUrl(oauthStateCreate('apple',    $redirect)) : null;

$hasOAuth = $googleUrl || $facebookUrl || $appleUrl;
?><!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= h($title) ?> — WorkTrack</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="/webapp/assets/css/style.css">
</head>
<body class="theme-dark" style="display:flex;align-items:center;justify-content:center;min-height:100vh;padding:1.5rem">

<div class="auth-card">
    <!-- Brand -->
    <div class="auth-brand">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
            <path d="M6 12H18M3 6H7M17 6H21M3 18H7M17 18H21M7 6V18M17 6V18"/>
        </svg>
        <span>WorkTrack</span>
    </div>

    <h1 class="auth-title"><?= h($title) ?></h1>

    <?php if ($error): ?>
    <div class="auth-error"><?= h($error) ?></div>
    <?php endif; ?>

    <!-- OAuth buttons -->
    <?php if ($hasOAuth): ?>
    <div class="auth-oauth">
        <?php if ($appleUrl): ?>
        <a href="<?= h($appleUrl) ?>" class="btn-oauth btn-apple">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.4c1.39.07 2.35.74 3.15.8.96-.19 1.88-.88 3.38-.94 1.72.07 3.01.81 3.84 2.06-3.55 2.13-2.72 6.43.63 7.67-.37.99-.85 1.96-1.96 3.29zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
            </svg>
            Continue with Apple
        </a>
        <?php endif; ?>

        <?php if ($googleUrl): ?>
        <a href="<?= h($googleUrl) ?>" class="btn-oauth btn-google">
            <svg width="17" height="17" viewBox="0 0 24 24">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
            </svg>
            Continue with Google
        </a>
        <?php endif; ?>

        <?php if ($facebookUrl): ?>
        <a href="<?= h($facebookUrl) ?>" class="btn-oauth btn-facebook">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor">
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
            </svg>
            Continue with Facebook
        </a>
        <?php endif; ?>
    </div>

    <div class="auth-divider"><span>or</span></div>
    <?php endif; ?>

    <!-- Email / password form -->
    <form method="POST" class="auth-form">
        <input type="hidden" name="_csrf" value="<?= h(csrfGenerate()) ?>">
        <?php if ($redirect): ?>
        <input type="hidden" name="redirect" value="<?= h($redirect) ?>">
        <?php endif; ?>

        <div class="form-group">
            <label class="form-label">Email address</label>
            <input type="email" name="email" class="form-input" required
                   value="<?= h($_POST['email'] ?? '') ?>"
                   placeholder="you@example.com" autocomplete="email">
        </div>

        <div class="form-group">
            <label class="form-label">Password</label>
            <input type="password" name="password" class="form-input" required
                   placeholder="••••••••••"
                   autocomplete="<?= $isRegister ? 'new-password' : 'current-password' ?>">
        </div>

        <?php if ($isRegister): ?>
        <div class="form-group">
            <label class="form-label">Confirm password</label>
            <input type="password" name="confirm" class="form-input" required
                   placeholder="••••••••••" autocomplete="new-password">
        </div>
        <?php endif; ?>

        <button type="submit" class="btn btn-primary btn-block" style="margin-top:0.5rem">
            <?= $isRegister ? 'Create account' : 'Sign in' ?>
        </button>
    </form>

    <div class="auth-switch">
        <?= $isRegister ? 'Already have an account?' : "Don't have an account?" ?>
        <a href="?mode=<?= $switchMode ?><?= $redirect ? '&redirect=' . urlencode($redirect) : '' ?>">
            <?= h($switchLabel) ?>
        </a>
    </div>
</div>

</body>
</html>
