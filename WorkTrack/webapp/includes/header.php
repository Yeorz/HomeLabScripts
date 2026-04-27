<?php
$pageTitle  = $pageTitle  ?? 'WorkTrack';
$activePage = $activePage ?? 'dashboard';

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/functions.php';
require_once __DIR__ . '/auth.php';
$settings   = getSettings();
$theme      = $settings['theme'];
$unitSystem = $settings['unit_system'];

// Resolve signed-in user for the nav
$_navUser     = getAuthUser();
$_navDbUser   = null;
if ($_navUser) {
    $s = getDB()->prepare('SELECT email, name FROM users WHERE id = ?');
    $s->execute([$_navUser['id']]);
    $_navDbUser = $s->fetch() ?: null;
}
$_navLabel    = $_navDbUser['name'] ?: ($_navDbUser['email'] ? explode('@', $_navDbUser['email'])[0] : 'Account');
$_navInitials = strtoupper(mb_substr($_navLabel, 0, 2));
$_currentUrl  = '/webapp' . ($_SERVER['REQUEST_URI'] ?? '/');
?><!DOCTYPE html>
<html lang="en" data-theme="<?= h($theme) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#080b12">
    <meta name="csrf-token" content="<?= h(csrfGenerate()) ?>">
    <title><?= h($pageTitle) ?> — WorkTrack</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap">
    <link rel="stylesheet" href="/webapp/assets/css/style.css">
</head>
<body class="theme-<?= h($theme) ?>">

<nav class="nav">
    <div class="nav-inner">
        <a href="/webapp/" class="nav-brand">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
                <path d="M6 12H18M3 6H7M17 6H21M3 18H7M17 18H21M7 6V18M17 6V18"/>
            </svg>
            WorkTrack
        </a>

        <div class="nav-links">
            <a href="/webapp/"              class="nav-link<?= $activePage === 'dashboard' ? ' active' : '' ?>">Dashboard</a>
            <a href="/webapp/history.php"   class="nav-link<?= $activePage === 'history'   ? ' active' : '' ?>">History</a>
            <a href="/webapp/exercises.php" class="nav-link<?= $activePage === 'exercises' ? ' active' : '' ?>">Exercises</a>
            <a href="/webapp/settings.php"  class="nav-link<?= $activePage === 'settings'  ? ' active' : '' ?>">Settings</a>
        </div>

        <!-- User state — right side of nav -->
        <?php if ($_navDbUser): ?>
        <div class="nav-user">
            <div class="nav-avatar"><?= h($_navInitials) ?></div>
            <span class="nav-user-name"><?= h($_navLabel) ?></span>
            <a href="/webapp/auth/logout.php" class="nav-link" style="flex-shrink:0" title="Sign out">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                    <polyline points="16 17 21 12 16 7"/>
                    <line x1="21" y1="12" x2="9" y2="12"/>
                </svg>
            </a>
        </div>
        <?php else: ?>
        <div class="nav-user">
            <a href="/webapp/auth/login.php?redirect=<?= urlencode($_currentUrl) ?>"
               class="btn btn-primary btn-sm" style="flex-shrink:0">Sign in</a>
        </div>
        <?php endif; ?>

        <button class="nav-toggle" id="navToggle" aria-label="Open menu">
            <span></span><span></span><span></span>
        </button>
    </div>
</nav>

<div class="nav-mobile" id="navMobile">
    <a href="/webapp/"              class="nav-mobile-link<?= $activePage === 'dashboard' ? ' active' : '' ?>">Dashboard</a>
    <a href="/webapp/history.php"   class="nav-mobile-link<?= $activePage === 'history'   ? ' active' : '' ?>">History</a>
    <a href="/webapp/exercises.php" class="nav-mobile-link<?= $activePage === 'exercises' ? ' active' : '' ?>">Exercises</a>
    <a href="/webapp/settings.php"  class="nav-mobile-link<?= $activePage === 'settings'  ? ' active' : '' ?>">Settings</a>
    <?php if ($_navDbUser): ?>
    <a href="/webapp/auth/logout.php" class="nav-mobile-link" style="color:var(--danger)">Sign out</a>
    <?php else: ?>
    <a href="/webapp/auth/login.php?redirect=<?= urlencode($_currentUrl) ?>" class="nav-mobile-link">Sign in</a>
    <?php endif; ?>
</div>

<main class="main">
<div class="container">
