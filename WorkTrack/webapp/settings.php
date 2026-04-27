<?php
$pageTitle  = 'Settings';
$activePage = 'settings';
require_once __DIR__ . '/includes/header.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrfToken = $_POST['_csrf'] ?? '';
    if (!csrfVerify($csrfToken)) {
        http_response_code(403);
        exit('Invalid CSRF token');
    }
    $unit  = in_array($_POST['unit_system'] ?? '', ['metric', 'imperial']) ? $_POST['unit_system'] : 'metric';
    $theme = in_array($_POST['theme']       ?? '', ['dark', 'light'])      ? $_POST['theme']       : 'dark';
    updateSettings($unit, $theme);
    header('Location: /webapp/settings.php?saved=1');
    exit;
}

$saved = isset($_GET['saved']);
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>Settings</h1>
        <p>Customize WorkTrack to your preference</p>
    </div>
</div>

<?php if ($saved): ?>
<div class="card" style="border-color:var(--success);background:rgba(34,201,131,0.08);margin-bottom:1.5rem">
    <div class="flex gap-1 items-center" style="color:var(--success)">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>
        <span style="font-weight:600">Settings saved!</span>
    </div>
</div>
<?php endif; ?>

<form method="POST" style="max-width:600px">
    <div class="settings-section">
        <div class="settings-section-title">Units</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Unit system</div>
                <div class="settings-row-sub">Metric: kg / km &nbsp;·&nbsp; Imperial: lbs / miles</div>
            </div>
            <select name="unit_system" class="form-select" style="width:auto"
                    onchange="this.form.submit()">
                <option value="metric"   <?= $unitSystem === 'metric'   ? 'selected' : '' ?>>Metric</option>
                <option value="imperial" <?= $unitSystem === 'imperial' ? 'selected' : '' ?>>Imperial</option>
            </select>
        </div>
    </div>

    <div class="settings-section">
        <div class="settings-section-title">Appearance</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Dark theme</div>
                <div class="settings-row-sub">Recommended for gym use</div>
            </div>
            <label class="toggle">
                <input type="checkbox" id="themeToggle"
                       <?= $settings['theme'] === 'dark' ? 'checked' : '' ?>
                       onchange="submitTheme(this)">
                <span class="toggle-slider"></span>
            </label>
        </div>
    </div>

    <div class="settings-section">
        <div class="settings-section-title">About WorkTrack</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Version</div>
                <div class="settings-row-sub">Workout tracker — PHP web app</div>
            </div>
            <span class="badge badge-muted">v1.0</span>
        </div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Database</div>
                <div class="settings-row-sub">MariaDB / MySQL</div>
            </div>
            <?php
            // Only show version to authenticated users to avoid unnecessary info disclosure
            if (getAuthUser()) {
                try {
                    $version = getDB()->query('SELECT VERSION()')->fetchColumn();
                    echo '<span class="badge badge-accent">' . h($version) . '</span>';
                } catch (Exception $e) {
                    echo '<span class="badge badge-danger">Connection failed</span>';
                }
            } else {
                echo '<span class="badge badge-muted">MariaDB</span>';
            }
            ?>
        </div>
    </div>

    <input type="hidden" name="theme"  id="themeValue" value="<?= h($settings['theme']) ?>">
    <input type="hidden" name="_csrf" value="<?= h(csrfGenerate()) ?>">
    <button type="submit" id="realSubmit" style="display:none"></button>
</form>

<script>
function submitTheme(cb) {
    document.getElementById('themeValue').value = cb.checked ? 'dark' : 'light';
    document.getElementById('realSubmit').click();
}
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
