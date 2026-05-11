<!DOCTYPE html>
<html lang="en" data-section="<?= h($section ?? 'default') ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= h($page_title ?? setting('site_name')) ?> — <?= h(setting('site_name')) ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
    <link rel="stylesheet" href="/assets/css/main.css">
    <?php if (($section ?? '') === 'work'): ?>
    <link rel="stylesheet" href="/assets/css/work.css">
    <?php elseif (($section ?? '') === 'personal'): ?>
    <link rel="stylesheet" href="/assets/css/personal.css">
    <?php endif; ?>
</head>
<body>
    <nav class="site-nav">
        <a href="/" class="nav-brand"><?= h(setting('site_name')) ?></a>
        <ul class="nav-links">
            <li><a href="/work" class="nav-link <?= ($section ?? '') === 'work' ? 'active' : '' ?>">Work</a></li>
            <li><a href="/personal" class="nav-link <?= ($section ?? '') === 'personal' ? 'active' : '' ?>">Personal</a></li>
            <li><a href="/cv" class="nav-link <?= ($section ?? '') === 'cv' ? 'active' : '' ?>">CV</a></li>
            <li><a href="/contact" class="nav-link <?= ($section ?? '') === 'contact' ? 'active' : '' ?>">Contact</a></li>
        </ul>
        <button class="nav-toggle" aria-label="Toggle menu">&#9776;</button>
    </nav>

    <main class="site-main">
        <?= $content ?>
    </main>

    <footer class="site-footer">
        <p>&copy; <?= date('Y') ?> <?= h(setting('owner_name')) ?></p>
    </footer>

    <script src="/assets/js/main.js"></script>
</body>
</html>
