<?php
require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_login();

$pdo = db();

$total_work     = $pdo->query('SELECT COUNT(*) FROM articles WHERE section = "work" AND status = "published"')->fetchColumn();
$total_personal = $pdo->query('SELECT COUNT(*) FROM articles WHERE section = "personal" AND status = "published"')->fetchColumn();
$total_drafts   = $pdo->query('SELECT COUNT(*) FROM articles WHERE status = "draft"')->fetchColumn();
$unread_msgs    = $pdo->query('SELECT COUNT(*) FROM contact_messages WHERE read_at IS NULL')->fetchColumn();

$recent = $pdo->query(
    'SELECT id, title, section, status, updated_at FROM articles ORDER BY updated_at DESC LIMIT 5'
)->fetchAll();

$admin_title  = 'Dashboard';
$active_nav   = 'dashboard';
$topbar_actions = '<a href="/admin/editor.php" class="btn btn-primary btn-sm">+ New Article</a>';

ob_start();
?>
<div class="stat-grid">
    <div class="stat-card stat-card--work">
        <span class="stat-number"><?= $total_work ?></span>
        <span class="stat-label">Work Articles</span>
    </div>
    <div class="stat-card stat-card--personal">
        <span class="stat-number"><?= $total_personal ?></span>
        <span class="stat-label">Personal Posts</span>
    </div>
    <div class="stat-card">
        <span class="stat-number"><?= $total_drafts ?></span>
        <span class="stat-label">Drafts</span>
    </div>
    <div class="stat-card <?= $unread_msgs ? 'stat-card--alert' : '' ?>">
        <span class="stat-number"><?= $unread_msgs ?></span>
        <span class="stat-label">Unread Messages</span>
    </div>
</div>

<div class="admin-section">
    <h2>Recent Articles</h2>
    <?php if ($recent): ?>
    <table class="admin-table">
        <thead>
            <tr><th>Title</th><th>Section</th><th>Status</th><th>Updated</th><th></th></tr>
        </thead>
        <tbody>
            <?php foreach ($recent as $row): ?>
            <tr>
                <td><?= h($row['title']) ?></td>
                <td><span class="badge badge--<?= h($row['section']) ?>"><?= h($row['section']) ?></span></td>
                <td><span class="badge badge--<?= h($row['status']) ?>"><?= h($row['status']) ?></span></td>
                <td><?= time_ago($row['updated_at']) ?></td>
                <td><a href="/admin/editor.php?id=<?= $row['id'] ?>" class="btn btn-ghost btn-xs">Edit</a></td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
    <?php else: ?>
    <p class="empty-state">No articles yet. <a href="/admin/editor.php">Create one</a>.</p>
    <?php endif; ?>
</div>
<?php
$admin_content = ob_get_clean();
require __DIR__ . '/includes/layout.php';
