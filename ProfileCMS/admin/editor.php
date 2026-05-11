<?php
require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_login();

$id      = (int)($_GET['id'] ?? 0);
$article = null;
$errors  = [];

if ($id) {
    $article = db()->prepare('SELECT * FROM articles WHERE id = ?');
    $article->execute([$id]);
    $article = $article->fetch();
    if (!$article) { header('Location: /admin/articles.php'); exit; }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verify_csrf();

    $title   = trim($_POST['title']   ?? '');
    $excerpt = trim($_POST['excerpt'] ?? '');
    $content = $_POST['content'] ?? '';   // HTML from Quill — not escaped, stored as-is
    $section = $_POST['section'] ?? 'work';
    $status  = $_POST['status']  ?? 'draft';
    $slug    = trim($_POST['slug'] ?? '') ?: slugify($title);

    if (!in_array($section, ['work', 'personal', 'cv'], true)) $section = 'work';
    if (!in_array($status,  ['draft', 'published'],     true)) $status  = 'draft';

    if (!$title) $errors[] = 'Title is required.';
    if (!$slug)  $errors[] = 'Slug could not be generated.';

    if (!$errors) {
        if ($id) {
            db()->prepare(
                'UPDATE articles SET title=?, slug=?, excerpt=?, content=?, section=?, status=? WHERE id=?'
            )->execute([$title, $slug, $excerpt, $content, $section, $status, $id]);
        } else {
            db()->prepare(
                'INSERT INTO articles (title, slug, excerpt, content, section, status) VALUES (?, ?, ?, ?, ?, ?)'
            )->execute([$title, $slug, $excerpt, $content, $section, $status]);
            $id = db()->lastInsertId();
        }
        header('Location: /admin/articles.php?saved=1');
        exit;
    }
}

$admin_title = $article ? 'Edit: ' . h($article['title']) : 'New Article';
$active_nav  = 'articles';

$head_extra = '
<link rel="stylesheet" href="https://cdn.quilljs.com/1.3.7/quill.snow.css">
';
$foot_extra = '
<script src="https://cdn.quilljs.com/1.3.7/quill.min.js"></script>
<script src="/assets/js/editor.js"></script>
';

ob_start();
?>
<?php if ($errors): ?>
<div class="alert alert-error">
    <?php foreach ($errors as $e): ?><p><?= h($e) ?></p><?php endforeach; ?>
</div>
<?php endif; ?>

<form id="editor-form" method="post" action="/admin/editor.php<?= $id ? '?id=' . $id : '' ?>">
    <input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>">
    <!-- Quill outputs HTML here before submit -->
    <input type="hidden" name="content" id="content-input">

    <div class="editor-layout">
        <div class="editor-main">
            <div class="form-group">
                <input type="text" name="title" id="title" class="editor-title-input"
                       placeholder="Article title…"
                       value="<?= h($article['title'] ?? '') ?>" required>
            </div>

            <div id="quill-editor" class="quill-wrapper">
                <?= $article['content'] ?? '' ?>
            </div>
        </div>

        <aside class="editor-sidebar">
            <div class="editor-meta-card">
                <div class="form-group">
                    <label>Status</label>
                    <select name="status">
                        <option value="draft"     <?= ($article['status'] ?? 'draft')  === 'draft'     ? 'selected' : '' ?>>Draft</option>
                        <option value="published" <?= ($article['status'] ?? '')        === 'published' ? 'selected' : '' ?>>Published</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Section</label>
                    <select name="section" id="section-select">
                        <option value="work"     <?= ($article['section'] ?? 'work') === 'work'     ? 'selected' : '' ?>>Work</option>
                        <option value="personal" <?= ($article['section'] ?? '')     === 'personal' ? 'selected' : '' ?>>Personal</option>
                        <option value="cv"       <?= ($article['section'] ?? '')     === 'cv'       ? 'selected' : '' ?>>CV</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Slug</label>
                    <input type="text" name="slug" id="slug-input"
                           value="<?= h($article['slug'] ?? '') ?>" placeholder="auto-generated">
                </div>
                <div class="form-group">
                    <label>Excerpt</label>
                    <textarea name="excerpt" rows="3" placeholder="Short summary (optional)"><?= h($article['excerpt'] ?? '') ?></textarea>
                </div>
                <div class="editor-actions">
                    <button type="submit" class="btn btn-primary btn-block">Save</button>
                    <a href="/admin/articles.php" class="btn btn-ghost btn-block">Cancel</a>
                    <?php if ($article && $article['status'] === 'published'): ?>
                    <a href="/<?= h($article['section']) ?>/<?= h($article['slug']) ?>"
                       target="_blank" class="btn btn-ghost btn-block">View &uarr;</a>
                    <?php endif; ?>
                </div>
            </div>
        </aside>
    </div>
</form>
<?php
$admin_content = ob_get_clean();
require __DIR__ . '/includes/layout.php';
