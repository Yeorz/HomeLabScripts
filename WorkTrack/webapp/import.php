<?php
$pageTitle  = 'Import exercises';
$activePage = 'exercises';
require_once __DIR__ . '/includes/header.php';

$allExercises = require __DIR__ . '/data/exercises.php';

// Existing exercises by name_en and name_nl (lowercase)
$stmt     = getDB()->query('SELECT LOWER(name_nl) AS nl, LOWER(COALESCE(name_en, \'\')) AS en FROM exercises');
$existing = [];
foreach ($stmt->fetchAll() as $row) {
    if ($row['nl']) $existing[$row['nl']] = true;
    if ($row['en']) $existing[$row['en']] = true;
}

// Group by muscle group, mark new vs existing
$grouped  = [];
$newCount = 0;
foreach ($allExercises as $ex) {
    [$namNl, $namEn, $group, $cat, $equip] = $ex;
    $isNew = !isset($existing[mb_strtolower($namNl)]) && !isset($existing[mb_strtolower($namEn)]);
    if ($isNew) $newCount++;
    $grouped[$group][] = [
        'name_nl'    => $namNl,
        'name_en'    => $namEn,
        'spiergroep' => $group,
        'categorie'  => $cat,
        'materiaal'  => $equip,
        'is_new'     => $isNew,
    ];
}
ksort($grouped);

$totalCount    = count($allExercises);
$existingCount = $totalCount - $newCount;

$equipmentEN = [
    'barbell'    => 'Barbell',
    'dumbbell'   => 'Dumbbell',
    'machine'    => 'Machine',
    'cable'      => 'Cable',
    'bodyweight' => 'Bodyweight',
    'kettlebell' => 'Kettlebell',
    'bands'      => 'Resistance Bands',
    'cardio'     => 'Cardio',
    'overig'     => 'Other',
];
$catIcon = [
    'kracht'        => '🏋️',
    'cardio'        => '🏃',
    'flexibiliteit' => '🧘',
    'overig'        => '⚡',
];
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>Import exercises</h1>
        <p>Select which exercises to add to your library</p>
    </div>
    <a href="/webapp/exercises.php" class="btn btn-secondary">← Back to exercises</a>
</div>

<div class="card card-sm mb-3" style="display:flex;align-items:center;gap:2rem;flex-wrap:wrap">
    <div>
        <div class="stat-label">Total in library</div>
        <div style="font-size:1.4rem;font-weight:800;color:var(--text-1)"><?= $totalCount ?></div>
    </div>
    <div>
        <div class="stat-label">New to import</div>
        <div style="font-size:1.4rem;font-weight:800;color:var(--accent)" id="newCountDisplay"><?= $newCount ?></div>
    </div>
    <div>
        <div class="stat-label">Already present</div>
        <div style="font-size:1.4rem;font-weight:800;color:var(--text-3)"><?= $existingCount ?></div>
    </div>
    <div style="margin-left:auto;display:flex;gap:0.75rem;flex-wrap:wrap">
        <button class="btn btn-secondary btn-sm" onclick="selectAll(true)">Select all</button>
        <button class="btn btn-secondary btn-sm" onclick="selectAll(false)">Deselect all</button>
        <button class="btn btn-primary" id="btnImport" onclick="doImport()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            <span id="btnImportLabel">Import selected (<span id="selectedCount"><?= $newCount ?></span>)</span>
        </button>
    </div>
</div>

<div id="importResult" style="display:none" class="card card-sm mb-3"></div>

<?php foreach ($grouped as $groupName => $exercises):
    $newInGroup = count(array_filter($exercises, fn($e) => $e['is_new']));
?>
<div class="import-group mb-2" id="group-<?= h(str_replace(' ', '-', $groupName)) ?>">
    <div class="import-group-header" onclick="toggleGroup(this)">
        <div style="display:flex;align-items:center;gap:0.75rem;flex:1">
            <div>
                <div class="import-group-title"><?= h($groupName) ?></div>
                <div class="import-group-meta">
                    <?= count($exercises) ?> exercises
                    <?php if ($newInGroup > 0): ?>
                    &nbsp;·&nbsp;<span style="color:var(--accent)"><?= $newInGroup ?> new</span>
                    <?php else: ?>
                    &nbsp;·&nbsp;<span style="color:var(--text-3)">all already present</span>
                    <?php endif; ?>
                </div>
            </div>
        </div>
        <div style="display:flex;align-items:center;gap:1rem">
            <label class="group-select-all" onclick="event.stopPropagation()">
                <input type="checkbox" class="group-checkbox"
                       data-group="<?= h($groupName) ?>"
                       <?= $newInGroup > 0 ? 'checked' : '' ?>
                       onchange="toggleGroupExercises(this)">
                <span class="text-sm text-muted">Select group</span>
            </label>
            <svg class="chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>
        </div>
    </div>

    <div class="import-group-body">
        <?php foreach ($exercises as $ex):
            $equip = $equipmentEN[$ex['materiaal']] ?? $ex['materiaal'];
            $icon  = $catIcon[$ex['categorie']] ?? '💪';
        ?>
        <label class="import-exercise-row <?= !$ex['is_new'] ? 'is-existing' : '' ?>"
               data-group="<?= h($ex['spiergroep']) ?>">
            <input type="checkbox"
                   class="exercise-checkbox"
                   data-name_nl="<?= h($ex['name_nl']) ?>"
                   data-name_en="<?= h($ex['name_en']) ?>"
                   data-spiergroep="<?= h($ex['spiergroep']) ?>"
                   data-categorie="<?= h($ex['categorie']) ?>"
                   data-materiaal="<?= h($ex['materiaal']) ?>"
                   <?= $ex['is_new'] ? 'checked' : 'disabled' ?>
                   onchange="updateSelectedCount()">
            <div class="import-exercise-icon"><?= $icon ?></div>
            <div class="import-exercise-info">
                <span class="import-exercise-name"><?= h($ex['name_en']) ?></span>
                <?php if ($ex['name_nl'] && $ex['name_nl'] !== $ex['name_en']): ?>
                <span class="import-exercise-en"><?= h($ex['name_nl']) ?></span>
                <?php endif; ?>
            </div>
            <div class="import-exercise-tags">
                <span class="badge badge-muted"><?= h($equip) ?></span>
                <?php if (!$ex['is_new']): ?>
                <span class="badge" style="background:rgba(0,212,163,0.12);color:var(--accent)">Existing</span>
                <?php endif; ?>
            </div>
        </label>
        <?php endforeach; ?>
    </div>
</div>
<?php endforeach; ?>

<div style="height:2rem"></div>

<style>
.import-group {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
}
.import-group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    cursor: pointer;
    gap: 1rem;
    user-select: none;
    transition: background var(--transition);
}
.import-group-header:hover { background: var(--bg-elevated); }
.import-group-title { font-size: 0.95rem; font-weight: 700; color: var(--text-1); }
.import-group-meta  { font-size: 0.78rem; color: var(--text-3); margin-top: 1px; }
.chevron { transition: transform 0.2s ease; color: var(--text-3); flex-shrink: 0; }
.import-group.collapsed .chevron { transform: rotate(-90deg); }
.import-group-body { border-top: 1px solid var(--border); }
.import-group.collapsed .import-group-body { display: none; }
.group-select-all { display: flex; align-items: center; gap: 0.4rem; cursor: pointer; }
.group-select-all input { accent-color: var(--primary); width: 16px; height: 16px; cursor: pointer; }
.import-exercise-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.65rem 1.25rem;
    border-bottom: 1px solid var(--border);
    cursor: pointer;
    transition: background var(--transition);
}
.import-exercise-row:last-child { border-bottom: none; }
.import-exercise-row:hover { background: var(--bg-elevated); }
.import-exercise-row.is-existing { opacity: 0.45; }
.import-exercise-row.is-existing:hover { background: transparent; cursor: default; }
.import-exercise-row input[type="checkbox"] { accent-color: var(--primary); width: 16px; height: 16px; flex-shrink: 0; cursor: pointer; }
.import-exercise-row input:disabled { cursor: default; }
.import-exercise-icon { font-size: 1.1rem; width: 28px; text-align: center; flex-shrink: 0; }
.import-exercise-info { flex: 1; min-width: 0; display: flex; align-items: baseline; gap: 0.6rem; flex-wrap: wrap; }
.import-exercise-name { font-size: 0.9rem; font-weight: 600; color: var(--text-1); }
.import-exercise-en   { font-size: 0.78rem; color: var(--text-3); }
.import-exercise-tags { display: flex; gap: 0.4rem; flex-shrink: 0; flex-wrap: wrap; }
</style>

<script>
function updateSelectedCount() {
    const n = document.querySelectorAll('.exercise-checkbox:checked:not(:disabled)').length;
    document.getElementById('selectedCount').textContent = n;
    document.querySelectorAll('.import-group').forEach(group => {
        const boxes   = group.querySelectorAll('.exercise-checkbox:not(:disabled)');
        const checked = group.querySelectorAll('.exercise-checkbox:checked:not(:disabled)');
        const gc = group.querySelector('.group-checkbox');
        if (gc) gc.checked = boxes.length > 0 && checked.length > 0;
    });
}

function selectAll(state) {
    document.querySelectorAll('.exercise-checkbox:not(:disabled)').forEach(cb => cb.checked = state);
    updateSelectedCount();
}

function toggleGroupExercises(groupCheckbox) {
    const groupName = groupCheckbox.dataset.group;
    document.querySelectorAll(`.exercise-checkbox[data-spiergroep="${CSS.escape(groupName)}"]:not(:disabled)`)
        .forEach(cb => cb.checked = groupCheckbox.checked);
    updateSelectedCount();
}

function toggleGroup(header) {
    header.closest('.import-group').classList.toggle('collapsed');
}

async function doImport() {
    const checkboxes = document.querySelectorAll('.exercise-checkbox:checked:not(:disabled)');
    if (!checkboxes.length) { showToast('No exercises selected', 'error'); return; }

    const exercises = Array.from(checkboxes).map(cb => ({
        name_nl:    cb.dataset.name_nl,
        name_en:    cb.dataset.name_en,
        spiergroep: cb.dataset.spiergroep,
        categorie:  cb.dataset.categorie,
        materiaal:  cb.dataset.materiaal,
    }));

    const btn = document.getElementById('btnImport');
    btn.disabled = true;
    document.getElementById('btnImportLabel').textContent = 'Importing...';

    try {
        const res  = await fetch('/webapp/api/import.php', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({exercises})
        });
        const data = await res.json();
        if (data.error) throw new Error(data.error);

        const resultEl = document.getElementById('importResult');
        resultEl.style.display    = 'block';
        resultEl.style.borderColor = 'var(--success)';
        resultEl.style.background  = 'rgba(34,201,131,0.08)';
        resultEl.innerHTML = `
            <div style="display:flex;align-items:center;gap:0.75rem;color:var(--success)">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>
                <div>
                    <strong>${data.inserted} exercises imported</strong>
                    ${data.skipped ? ` · ${data.skipped} skipped (already present)` : ''}
                    ${data.errors?.length ? ` · <span style="color:var(--danger)">${data.errors.length} errors</span>` : ''}
                </div>
            </div>
            ${data.errors?.length ? `<div style="margin-top:0.5rem;font-size:0.8rem;color:var(--danger)">${data.errors.map(escHtml).join('<br>')}</div>` : ''}
            <div style="margin-top:0.75rem">
                <a href="/webapp/exercises.php" class="btn btn-primary btn-sm">Go to exercise library →</a>
            </div>`;

        checkboxes.forEach(cb => {
            cb.disabled = true;
            cb.closest('.import-exercise-row')?.classList.add('is-existing');
        });

        showToast(`${data.inserted} exercises imported!`, 'success', 4000);
        document.getElementById('newCountDisplay').textContent = 0;
        btn.disabled = false;
        document.getElementById('btnImportLabel').innerHTML = 'Import selected (<span id="selectedCount">0</span>)';
        updateSelectedCount();

    } catch (err) {
        btn.disabled = false;
        document.getElementById('btnImportLabel').innerHTML = `Import selected (<span id="selectedCount">${document.querySelectorAll('.exercise-checkbox:checked:not(:disabled)').length}</span>)`;
        showToast(err.message || 'Import failed', 'error');
    }
}

// Collapse groups that have no new exercises
document.querySelectorAll('.import-group').forEach(group => {
    if (!group.querySelectorAll('.exercise-checkbox:not(:disabled)').length) {
        group.classList.add('collapsed');
    }
});
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
