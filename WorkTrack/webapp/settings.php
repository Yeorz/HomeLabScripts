<?php
$pageTitle  = 'Instellingen';
$activePage = 'settings';
require_once __DIR__ . '/includes/header.php';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $unit  = in_array($_POST['unit_system'] ?? '', ['metric', 'imperial']) ? $_POST['unit_system'] : 'metric';
    $theme = in_array($_POST['theme'] ?? '', ['dark', 'light']) ? $_POST['theme'] : 'dark';
    updateSettings($unit, $theme);
    header('Location: /webapp/settings.php?saved=1');
    exit;
}

$saved = isset($_GET['saved']);
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>Instellingen</h1>
        <p>Pas WorkTrack aan naar jouw voorkeur</p>
    </div>
</div>

<?php if ($saved): ?>
<div class="card" style="border-color:var(--success);background:rgba(34,201,131,0.08);margin-bottom:1.5rem">
    <div class="flex gap-1 items-center" style="color:var(--success)">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>
        <span style="font-weight:600">Instellingen opgeslagen!</span>
    </div>
</div>
<?php endif; ?>

<form method="POST" style="max-width:600px">
    <div class="settings-section">
        <div class="settings-section-title">Eenheden</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Eenheidensysteem</div>
                <div class="settings-row-sub">Metrisch: kg/km &nbsp;·&nbsp; Imperiaal: lbs/miles</div>
            </div>
            <select name="unit_system" class="form-select" style="width:auto"
                    onchange="this.form.submit()">
                <option value="metric"   <?= $unitSystem === 'metric'   ? 'selected' : '' ?>>Metrisch (NL)</option>
                <option value="imperial" <?= $unitSystem === 'imperial' ? 'selected' : '' ?>>Imperiaal (VS)</option>
            </select>
        </div>
    </div>

    <div class="settings-section">
        <div class="settings-section-title">Weergave</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Donker thema</div>
                <div class="settings-row-sub">Aanbevolen voor gebruik in de sportschool</div>
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
        <div class="settings-section-title">Over WorkTrack</div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Versie</div>
                <div class="settings-row-sub">Basis workout tracker — stap 1</div>
            </div>
            <span class="badge badge-muted">v1.0</span>
        </div>
        <div class="settings-row">
            <div>
                <div class="settings-row-label">Database</div>
                <div class="settings-row-sub">MariaDB / MySQL</div>
            </div>
            <?php
            try {
                $version = getDB()->query('SELECT VERSION()')->fetchColumn();
                echo '<span class="badge badge-accent">' . h($version) . '</span>';
            } catch (Exception $e) {
                echo '<span class="badge badge-danger">Geen verbinding</span>';
            }
            ?>
        </div>
    </div>

    <!-- Hidden submit for JS -->
    <input type="hidden" name="theme" id="themeValue" value="<?= h($settings['theme']) ?>">
    <button type="submit" id="realSubmit" style="display:none"></button>
</form>

<script>
function submitTheme(cb) {
    const themeVal = cb.checked ? 'dark' : 'light';
    document.getElementById('themeValue').value = themeVal;
    document.getElementById('realSubmit').click();
}
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
