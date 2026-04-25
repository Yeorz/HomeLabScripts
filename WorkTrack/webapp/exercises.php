<?php
$pageTitle  = 'Exercises';
$activePage = 'exercises';
require_once __DIR__ . '/includes/header.php';

$pdo    = getDB();
$groups = $pdo->query('SELECT * FROM muscle_groups ORDER BY name_en')->fetchAll();

$categoryLabel = [
    'kracht'        => 'Strength',
    'cardio'        => 'Cardio',
    'flexibiliteit' => 'Flexibility',
    'overig'        => 'Other',
];
$equipmentLabel = [
    'barbell'    => 'Barbell',
    'dumbbell'   => 'Dumbbell',
    'machine'    => 'Machine',
    'cable'      => 'Cable',
    'bodyweight' => 'Bodyweight',
    'kettlebell' => 'Kettlebell',
    'bands'      => 'Resistance Bands',
    'cardio'     => 'Cardio',
    'overig'     => '',
];
$categoryIcon = [
    'kracht'        => '🏋️',
    'cardio'        => '🏃',
    'flexibiliteit' => '🧘',
    'overig'        => '⚡',
];
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>Exercises</h1>
        <p>Browse and manage your exercise library</p>
    </div>
    <div style="display:flex;gap:0.5rem">
        <a href="/webapp/import.php" class="btn btn-secondary">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            Import library
        </a>
        <button class="btn btn-primary" onclick="openNewExerciseModal()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            Custom exercise
        </button>
    </div>
</div>

<div class="flex gap-2 mb-3" style="flex-wrap:wrap">
    <div class="search-wrap" style="flex:1;min-width:200px">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input type="search" class="form-input" id="searchInput" placeholder="Search exercises...">
    </div>
</div>

<div class="filter-chips" id="filterChips">
    <button class="chip active" data-group="0">All</button>
    <?php foreach ($groups as $g): ?>
    <button class="chip" data-group="<?= $g['id'] ?>"><?= h($g['name_en']) ?></button>
    <?php endforeach; ?>
</div>

<div class="exercise-browser-grid" id="exerciseGrid">
    <div class="empty-state" style="grid-column:1/-1;padding:2rem">
        <p class="loading">Loading...</p>
    </div>
</div>

<!-- Add custom exercise modal -->
<div class="modal-backdrop" id="newExerciseModal">
    <div class="modal" style="max-height:auto">
        <div class="modal-header" style="padding-bottom:1rem;border-bottom:1px solid var(--border)">
            <h3>New exercise</h3>
            <button class="btn-icon" onclick="closeNewExerciseModal()">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
        </div>
        <div style="padding:1.25rem;overflow-y:auto">
            <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" class="form-input" id="newName" placeholder="e.g. Incline Bench Press">
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">Muscle group</label>
                    <select class="form-select" id="newGroup">
                        <option value="">— Select —</option>
                        <?php foreach ($groups as $g): ?>
                        <option value="<?= $g['id'] ?>"><?= h($g['name_en']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Category</label>
                    <select class="form-select" id="newCategory">
                        <option value="kracht">Strength</option>
                        <option value="cardio">Cardio</option>
                        <option value="flexibiliteit">Flexibility</option>
                        <option value="overig">Other</option>
                    </select>
                </div>
            </div>
            <div class="form-group">
                <label class="form-label">Equipment</label>
                <select class="form-select" id="newEquipment">
                    <option value="barbell">Barbell</option>
                    <option value="dumbbell">Dumbbell</option>
                    <option value="machine">Machine</option>
                    <option value="cable">Cable</option>
                    <option value="bodyweight">Bodyweight</option>
                    <option value="kettlebell">Kettlebell</option>
                    <option value="bands">Resistance Bands</option>
                    <option value="cardio">Cardio</option>
                    <option value="overig">Other</option>
                </select>
            </div>
            <div class="flex gap-1" style="justify-content:flex-end;margin-top:0.5rem">
                <button class="btn btn-secondary" onclick="closeNewExerciseModal()">Cancel</button>
                <button class="btn btn-primary" onclick="saveNewExercise()">Save</button>
            </div>
        </div>
    </div>
</div>

<script>
const EQUIPMENT_LABELS = <?= json_encode($equipmentLabel, JSON_UNESCAPED_UNICODE) ?>;
const CATEGORY_ICONS   = <?= json_encode($categoryIcon,   JSON_UNESCAPED_UNICODE) ?>;

let activeGroup  = 0;
let allExercises = [];

async function loadExercises() {
    const res  = await fetch('/webapp/api/exercises.php?action=list');
    allExercises = await res.json();
    renderGrid();
}

function renderGrid() {
    const q      = document.getElementById('searchInput').value.toLowerCase();
    const grid   = document.getElementById('exerciseGrid');
    const subset = allExercises.filter(e => {
        const matchGroup = !activeGroup || e.muscle_group_id == activeGroup;
        const matchQ     = !q || (e.name || '').toLowerCase().includes(q) || (e.name_nl || '').toLowerCase().includes(q);
        return matchGroup && matchQ;
    });

    if (!subset.length) {
        grid.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><div class="empty-state-icon">🔍</div><h3>No exercises found</h3></div>';
        return;
    }

    const byGroup = {};
    for (const e of subset) {
        const g = e.muscle_group || 'Other';
        (byGroup[g] = byGroup[g] || []).push(e);
    }

    let html = '';
    for (const [group, exs] of Object.entries(byGroup)) {
        html += `<div style="grid-column:1/-1" class="section-title">${escHtml(group)}</div>`;
        for (const e of exs) {
            const icon   = CATEGORY_ICONS[e.category] || '💪';
            const equip  = EQUIPMENT_LABELS[e.equipment] || '';
            const meta   = [e.muscle_group, equip].filter(Boolean).join(' · ');
            const custom = e.is_custom ? ' <span class="badge badge-accent" style="font-size:0.65rem">Custom</span>' : '';
            html += `
            <div class="exercise-card">
                <div class="exercise-card-icon">${icon}</div>
                <div class="exercise-card-info">
                    <div class="exercise-card-name">${escHtml(e.name || e.name_en || e.name_nl)}${custom}</div>
                    <div class="exercise-card-meta">${escHtml(meta)}</div>
                </div>
            </div>`;
        }
    }
    grid.innerHTML = html;
}

document.getElementById('filterChips').addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    document.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    activeGroup = parseInt(chip.dataset.group);
    renderGrid();
});

let searchTimer;
document.getElementById('searchInput').addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(renderGrid, 200);
});

function openNewExerciseModal()  { document.getElementById('newExerciseModal').classList.add('open'); }
function closeNewExerciseModal() { document.getElementById('newExerciseModal').classList.remove('open'); }

async function saveNewExercise() {
    const name = document.getElementById('newName').value.trim();
    if (!name) { showToast('Name is required', 'error'); return; }

    const res  = await fetch('/webapp/api/exercises.php?action=create', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            name_en:         name,
            muscle_group_id: document.getElementById('newGroup').value || null,
            category:        document.getElementById('newCategory').value,
            equipment:       document.getElementById('newEquipment').value,
        })
    });
    const data = await res.json();
    if (data.error) { showToast(data.error, 'error'); return; }

    showToast('Exercise saved!', 'success');
    closeNewExerciseModal();
    document.getElementById('newName').value = '';
    await loadExercises();
}

loadExercises();
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
