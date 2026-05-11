<?php
require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_login();

// Handle delete
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete') {
    verify_csrf();
    $id = (int)($_POST['id'] ?? 0);
    db()->prepare('DELETE FROM articles WHERE id = ?')->execute([$id]);
    header('Location: /admin/articles.php?deleted=1');
    exit;
}

$filter_section = $_GET['section'] ?? 'all';
$filter_status  = $_GET['status']  ?? 'all';

$where  = [];
$params = [];
if ($filter_section !== 'all') { $where[] = 'section = ?'; $params[] = $filter_section; }
if ($filter_status  !== 'all') { $where[] = 'status = ?';  $params[] = $filter_status; }
$sql = 'SELECT id, title, slug, section, status, created_at, updated_at FROM articles';
if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
$sql .= ' ORDER BY updated_at DESC';

$stmt = db()->prepare($sql);
$stmt->execute($params);
$articles = $stmt->fetchAll();

$admin_title    = 'Articles';
$active_nav     = 'articles';
$topbar_actions = '<a href="/admin/editor.php" class="btn btn-primary btn-sm">+ New Article</a>';

ob_start();
?>
<?php if (isset($_GET['deleted'])): ?>
<div class="alert alert-success">Article deleted.</div>
<?php endif; ?>
<?php if (isset($_GET['saved'])): ?>
<div class="alert alert-success">Article saved.</div>
<?php endif; ?>

<div class="filter-bar">
    <a href="?section=all" class="filter-btn <?= $filter_section === 'all' ? 'active' : '' ?>">All</a>
    <a href="?section=work" class="filter-btn filter-btn--work <?= $filter_section === 'work' ? 'active' : '' ?>">Work</a>
    <a href="?section=personal" class="filter-btn filter-btn--personal <?= $filter_section === 'personal' ? 'active' : '' ?>">Personal</a>
    <a href="?section=cv" class="filter-btn <?= $filter_section === 'cv' ? 'active' : '' ?>">CV</a>
    &nbsp;
    <a href="?section=<?= h($filter_section) ?>&status=published" class="filter-btn <?= $filter_status === 'published' ? 'active' : '' ?>">Published</a>
    <a href="?section=<?= h($filter_section) ?>&status=draft" class="filter-btn <?= $filter_status === 'draft' ? 'active' : '' ?>">Drafts</a>
</div>

<?php if ($articles): ?>
<table class="admin-table">
    <thead>
        <tr><th>Title</th><th>Section</th><th>Status</th><th>Updated</th><th></th></tr>
    </thead>
    <tbody>
        <?php foreach ($articles as $a): ?>
        <tr>
            <td>
                <a href="/admin/editor.php?id=<?= $a['id'] ?>" class="table-link"><?= h($a['title']) ?></a>
            </td>
            <td><span class="badge badge--<?= h($a['section']) ?>"><?= h($a['section']) ?></span></td>
            <td><span class="badge badge--<?= h($a['status']) ?>"><?= h($a['status']) ?></span></td>
            <td><?= time_ago($a['updated_at']) ?></td>
            <td class="table-actions">
                <a href="/admin/editor.php?id=<?= $a['id'] ?>" class="btn btn-ghost btn-xs">Edit</a>
                <form method="post" action="/admin/articles.php" style="display:inline"
                      onsubmit="return confirm('Delete this article?')">
                    <input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="id" value="<?= $a['id'] ?>">
                    <button type="submit" class="btn btn-danger btn-xs">Delete</button>
                </form>
            </td>
        </tr>
        <?php endforeach; ?>
    </tbody>
</table>
<?php else: ?>
<p class="empty-state">No articles found. <a href="/admin/editor.php">Create one</a>.</p>
<?php endif; ?>
<?php
$admin_content = ob_get_clean();
require __DIR__ . '/includes/layout.php';
