<?php
require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_login();

$saved = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verify_csrf();
    $fields = ['site_name', 'site_tagline', 'owner_name', 'linkedin_url', 'instagram_url', 'x_url', 'contact_email', 'cv_content'];
    $stmt   = db()->prepare('INSERT INTO settings (key_name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = ?');
    foreach ($fields as $field) {
        $val = $_POST[$field] ?? '';
        $stmt->execute([$field, $val, $val]);
    }
    $saved = true;
}

// Load current settings
$rows = db()->query('SELECT key_name, value FROM settings')->fetchAll(PDO::FETCH_KEY_PAIR);

$admin_title = 'Settings';
$active_nav  = 'settings';

$head_extra = '
<link rel="stylesheet" href="https://cdn.quilljs.com/1.3.7/quill.snow.css">
';
$foot_extra = '
<script src="https://cdn.quilljs.com/1.3.7/quill.min.js"></script>
<script src="/assets/js/editor.js"></script>
';

ob_start();
?>
<?php if ($saved): ?>
<div class="alert alert-success">Settings saved.</div>
<?php endif; ?>

<form method="post" action="/admin/settings.php" id="settings-form">
    <input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>">
    <input type="hidden" name="cv_content" id="cv-content-input">

    <div class="settings-section">
        <h2>Site Identity</h2>
        <div class="form-group">
            <label>Site Name</label>
            <input type="text" name="site_name" value="<?= h($rows['site_name'] ?? '') ?>">
        </div>
        <div class="form-group">
            <label>Tagline</label>
            <input type="text" name="site_tagline" value="<?= h($rows['site_tagline'] ?? '') ?>">
        </div>
        <div class="form-group">
            <label>Your Name</label>
            <input type="text" name="owner_name" value="<?= h($rows['owner_name'] ?? '') ?>">
        </div>
        <div class="form-group">
            <label>Contact Email</label>
            <input type="email" name="contact_email" value="<?= h($rows['contact_email'] ?? '') ?>">
        </div>
    </div>

    <div class="settings-section">
        <h2>Social Links</h2>
        <div class="form-group">
            <label>LinkedIn URL</label>
            <input type="url" name="linkedin_url" value="<?= h($rows['linkedin_url'] ?? '') ?>" placeholder="https://linkedin.com/in/...">
        </div>
        <div class="form-group">
            <label>Instagram URL</label>
            <input type="url" name="instagram_url" value="<?= h($rows['instagram_url'] ?? '') ?>" placeholder="https://instagram.com/...">
        </div>
        <div class="form-group">
            <label>X (Twitter) URL</label>
            <input type="url" name="x_url" value="<?= h($rows['x_url'] ?? '') ?>" placeholder="https://x.com/...">
        </div>
    </div>

    <div class="settings-section">
        <h2>CV Content</h2>
        <div id="cv-quill-editor" class="quill-wrapper">
            <?= $rows['cv_content'] ?? '' ?>
        </div>
    </div>

    <div class="form-actions">
        <button type="submit" class="btn btn-primary">Save settings</button>
    </div>
</form>
<?php
$admin_content = ob_get_clean();
require __DIR__ . '/includes/layout.php';
