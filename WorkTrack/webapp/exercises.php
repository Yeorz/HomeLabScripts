<?php
$pageTitle  = 'Oefeningen';
$activePage = 'exercises';
require_once __DIR__ . '/includes/header.php';

$pdo    = getDB();
$groups = $pdo->query('SELECT * FROM muscle_groups ORDER BY name_nl')->fetchAll();

$categoryLabel = [
    'kracht'        => 'Kracht',
    'cardio'        => 'Cardio',
    'flexibiliteit' => 'Flexibiliteit',
    'overig'        => 'Overig',
];
$equipmentLabel = [
    'barbell'    => 'Halter',
    'dumbbell'   => 'Dumbbell',
    'machine'    => 'Machine',
    'cable'      => 'Kabel',
    'bodyweight' => 'Lichaamsgewicht',
    'kettlebell' => 'Kettlebell',
    'bands'      => 'Weerstandsbanden',
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
        <h1>Oefeningen</h1>
        <p>Blader en beheer je oefeningenbibliotheek</p>
    </div>
    <button class="btn btn-primary" onclick="openNewExerciseModal()">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
        Oefening toevoegen
    </button>
</div>

<!-- Search + filter -->
<div class="flex gap-2 mb-3" style="flex-wrap:wrap">
    <div class="search-wrap" style="flex:1;min-width:200px">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input type="search" class="form-input" id="searchInput" placeholder="Zoek oefening...">
    </div>
</div>

<div class="filter-chips" id="filterChips">
    <button class="chip active" data-group="0">Alle</button>
    <?php foreach ($groups as $g): ?>
    <button class="chip" data-group="<?= $g['id'] ?>"><?= h($g['name_nl']) ?></button>
    <?php endforeach; ?>
</div>

<div class="exercise-browser-grid" id="exerciseGrid">
    <div class="empty-state" style="grid-column:1/-1;padding:2rem">
        <p class="loading">Laden...</p>
    </div>
</div>

<!-- Add custom exercise modal -->
<div class="modal-backdrop" id="newExerciseModal">
    <div class="modal" style="max-height:auto">
        <div class="modal-header" style="padding-bottom:1rem;border-bottom:1px solid var(--border)">
            <h3>Nieuwe oefening</h3>
            <button class="btn-icon" onclick="closeNewExerciseModal()">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
        </div>
        <div style="padding:1.25rem;overflow-y:auto">
            <div class="form-group">
                <label class="form-label">Naam (NL) *</label>
                <input type="text" class="form-input" id="newName" placeholder="Bijv. Schuine bankdrukken">
            </div>
            <div class="form-row">
                <div class="form-group">
                    <label class="form-label">Spiergroep</label>
                    <select class="form-select" id="newGroup">
                        <option value="">— Selecteer —</option>
                        <?php foreach ($groups as $g): ?>
                        <option value="<?= $g['id'] ?>"><?= h($g['name_nl']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Categorie</label>
                    <select class="form-select" id="newCategory">
                        <option value="kracht">Kracht</option>
                        <option value="cardio">Cardio</option>
                        <option value="flexibiliteit">Flexibiliteit</option>
                        <option value="overig">Overig</option>
                    </select>
                </div>
            </div>
            <div class="form-group">
                <label class="form-label">Materiaal</label>
                <select class="form-select" id="newEquipment">
                    <option value="barbell">Halter (barbell)</option>
                    <option value="dumbbell">Dumbbell</option>
                    <option value="machine">Machine</option>
                    <option value="cable">Kabel</option>
                    <option value="bodyweight">Lichaamsgewicht</option>
                    <option value="kettlebell">Kettlebell</option>
                    <option value="bands">Weerstandsbanden</option>
                    <option value="cardio">Cardio</option>
                    <option value="overig">Overig</option>
                </select>
            </div>
            <div class="flex gap-1" style="justify-content:flex-end;margin-top:0.5rem">
                <button class="btn btn-secondary" onclick="closeNewExerciseModal()">Annuleren</button>
                <button class="btn btn-primary" onclick="saveNewExercise()">Opslaan</button>
            </div>
        </div>
    </div>
</div>

<script>
const EQUIPMENT_LABELS = <?= json_encode($equipmentLabel, JSON_UNESCAPED_UNICODE) ?>;
const CATEGORY_ICONS   = <?= json_encode($categoryIcon,   JSON_UNESCAPED_UNICODE) ?>;

let activeGroup = 0;
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
        const matchQ     = !q || e.name_nl.toLowerCase().includes(q) || (e.name_en || '').toLowerCase().includes(q);
        return matchGroup && matchQ;
    });

    if (!subset.length) {
        grid.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><div class="empty-state-icon">🔍</div><h3>Geen oefeningen gevonden</h3></div>';
        return;
    }

    // Group by muscle_group
    const byGroup = {};
    for (const e of subset) {
        const g = e.muscle_group || 'Overig';
        (byGroup[g] = byGroup[g] || []).push(e);
    }

    let html = '';
    for (const [group, exs] of Object.entries(byGroup)) {
        html += `<div style="grid-column:1/-1" class="section-title">${escHtml(group)}</div>`;
        for (const e of exs) {
            const icon  = CATEGORY_ICONS[e.category] || '💪';
            const equip = EQUIPMENT_LABELS[e.equipment] || '';
            const meta  = [e.muscle_group, equip].filter(Boolean).join(' · ');
            const custom = e.is_custom ? ' <span class="badge badge-accent" style="font-size:0.65rem">Eigen</span>' : '';
            html += `
            <div class="exercise-card">
                <div class="exercise-card-icon">${icon}</div>
                <div class="exercise-card-info">
                    <div class="exercise-card-name">${escHtml(e.name_nl)}${custom}</div>
                    <div class="exercise-card-meta">${escHtml(meta)}</div>
                </div>
            </div>`;
        }
    }
    grid.innerHTML = html;
}

// Filter chips
document.getElementById('filterChips').addEventListener('click', e => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    document.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    activeGroup = parseInt(chip.dataset.group);
    renderGrid();
});

// Search
let searchTimer;
document.getElementById('searchInput').addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(renderGrid, 200);
});

// New exercise modal
function openNewExerciseModal()  { document.getElementById('newExerciseModal').classList.add('open'); }
function closeNewExerciseModal() { document.getElementById('newExerciseModal').classList.remove('open'); }

async function saveNewExercise() {
    const name = document.getElementById('newName').value.trim();
    if (!name) { showToast('Naam is verplicht', 'error'); return; }

    const res  = await fetch('/webapp/api/exercises.php?action=create', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            name_nl:         name,
            muscle_group_id: document.getElementById('newGroup').value || null,
            category:        document.getElementById('newCategory').value,
            equipment:       document.getElementById('newEquipment').value,
        })
    });
    const data = await res.json();
    if (data.error) { showToast(data.error, 'error'); return; }

    showToast('Oefening opgeslagen!', 'success');
    closeNewExerciseModal();
    document.getElementById('newName').value = '';
    await loadExercises();
}

loadExercises();
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
