<?php
require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_login();

// Mark all as read
db()->exec('UPDATE contact_messages SET read_at = NOW() WHERE read_at IS NULL');

$messages = db()->query(
    'SELECT * FROM contact_messages ORDER BY created_at DESC'
)->fetchAll();

// Handle delete
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete') {
    verify_csrf();
    db()->prepare('DELETE FROM contact_messages WHERE id = ?')->execute([(int)$_POST['id']]);
    header('Location: /admin/messages.php');
    exit;
}

$admin_title = 'Contact Messages';
$active_nav  = 'messages';

ob_start();
?>
<?php if ($messages): ?>
<div class="message-list">
    <?php foreach ($messages as $msg): ?>
    <div class="message-card">
        <div class="message-meta">
            <strong><?= h($msg['name']) ?></strong>
            <a href="mailto:<?= h($msg['email']) ?>"><?= h($msg['email']) ?></a>
            <time><?= date('d M Y H:i', strtotime($msg['created_at'])) ?></time>
        </div>
        <p class="message-body"><?= nl2br(h($msg['message'])) ?></p>
        <form method="post" onsubmit="return confirm('Delete this message?')">
            <input type="hidden" name="csrf_token" value="<?= h(csrf_token()) ?>">
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="id" value="<?= $msg['id'] ?>">
            <button type="submit" class="btn btn-danger btn-xs">Delete</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>
<?php else: ?>
<p class="empty-state">No messages yet.</p>
<?php endif; ?>
<?php
$admin_content = ob_get_clean();
require __DIR__ . '/includes/layout.php';
