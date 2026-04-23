<?php
$pageTitle  = $pageTitle  ?? 'WorkTrack';
$activePage = $activePage ?? 'dashboard';

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/functions.php';
$settings   = getSettings();
$theme      = $settings['theme'];
$unitSystem = $settings['unit_system'];
?><!DOCTYPE html>
<html lang="nl" data-theme="<?= h($theme) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#080b12">
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
            <a href="/webapp/" class="nav-link<?= $activePage === 'dashboard' ? ' active' : '' ?>">Dashboard</a>
            <a href="/webapp/history.php" class="nav-link<?= $activePage === 'history' ? ' active' : '' ?>">Geschiedenis</a>
            <a href="/webapp/exercises.php" class="nav-link<?= $activePage === 'exercises' ? ' active' : '' ?>">Oefeningen</a>
            <a href="/webapp/settings.php" class="nav-link<?= $activePage === 'settings' ? ' active' : '' ?>">Instellingen</a>
        </div>

        <button class="nav-toggle" id="navToggle" aria-label="Menu openen">
            <span></span><span></span><span></span>
        </button>
    </div>
</nav>

<div class="nav-mobile" id="navMobile">
    <a href="/webapp/" class="nav-mobile-link<?= $activePage === 'dashboard' ? ' active' : '' ?>">Dashboard</a>
    <a href="/webapp/history.php" class="nav-mobile-link<?= $activePage === 'history' ? ' active' : '' ?>">Geschiedenis</a>
    <a href="/webapp/exercises.php" class="nav-mobile-link<?= $activePage === 'exercises' ? ' active' : '' ?>">Oefeningen</a>
    <a href="/webapp/settings.php" class="nav-mobile-link<?= $activePage === 'settings' ? ' active' : '' ?>">Instellingen</a>
</div>

<main class="main">
<div class="container">
