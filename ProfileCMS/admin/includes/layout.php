<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= h($admin_title ?? 'Admin') ?> — CMS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
    <link rel="stylesheet" href="/assets/css/main.css">
    <link rel="stylesheet" href="/assets/css/admin.css">
    <?= $head_extra ?? '' ?>
</head>
<body class="admin-body">
    <div class="admin-shell">
        <aside class="admin-sidebar">
            <div class="admin-sidebar-brand">
                <a href="/admin/">CMS</a>
            </div>
            <nav class="admin-nav">
                <a href="/admin/" class="admin-nav-item <?= ($active_nav ?? '') === 'dashboard' ? 'active' : '' ?>">
                    <span class="nav-icon">&#9632;</span> Dashboard
                </a>
                <a href="/admin/articles.php" class="admin-nav-item <?= ($active_nav ?? '') === 'articles' ? 'active' : '' ?>">
                    <span class="nav-icon">&#9632;</span> Articles
                </a>
                <a href="/admin/messages.php" class="admin-nav-item <?= ($active_nav ?? '') === 'messages' ? 'active' : '' ?>">
                    <span class="nav-icon">&#9632;</span> Messages
                </a>
                <a href="/admin/settings.php" class="admin-nav-item <?= ($active_nav ?? '') === 'settings' ? 'active' : '' ?>">
                    <span class="nav-icon">&#9632;</span> Settings
                </a>
            </nav>
            <div class="admin-sidebar-footer">
                <a href="/" target="_blank" class="admin-nav-item">View site &uarr;</a>
                <a href="/admin/logout.php" class="admin-nav-item admin-nav-logout">Log out</a>
            </div>
        </aside>

        <div class="admin-content">
            <header class="admin-topbar">
                <h1 class="admin-page-title"><?= h($admin_title ?? '') ?></h1>
                <?= $topbar_actions ?? '' ?>
            </header>
            <main class="admin-main">
                <?= $admin_content ?>
            </main>
        </div>
    </div>
    <script src="/assets/js/main.js"></script>
    <?= $foot_extra ?? '' ?>
</body>
</html>
