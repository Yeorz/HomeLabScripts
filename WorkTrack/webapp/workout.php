<?php
require_once __DIR__ . '/includes/db.php';
require_once __DIR__ . '/includes/functions.php';

$pdo = getDB();

// Create new workout and redirect
if (!isset($_GET['id'])) {
    $stmt = $pdo->prepare('INSERT INTO workouts (name, date, start_time) VALUES (NULL, CURDATE(), NOW())');
    $stmt->execute();
    $id = $pdo->lastInsertId();
    header("Location: /webapp/workout.php?id=$id");
    exit;
}

$id      = (int)$_GET['id'];
$workout = getWorkoutWithExercises($id);
if (!$workout) {
    header('Location: /webapp/');
    exit;
}

$pageTitle  = $workout['name'] ?: 'Workout loggen';
$activePage = 'dashboard';
require_once __DIR__ . '/includes/header.php';

$equipmentLabels = [
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
$weightUnit = $unitSystem === 'imperial' ? 'lbs' : 'kg';
$distUnit   = $unitSystem === 'imperial' ? 'mi'  : 'km';
?>

<div id="workoutData"
     data-id="<?= $workout['id'] ?>"
     data-unit="<?= h($unitSystem) ?>"
     data-start="<?= h($workout['start_time']) ?>"
     data-finished="<?= $workout['end_time'] ? '1' : '0' ?>">
</div>

<!-- Toolbar -->
<div class="workout-toolbar">
    <div class="workout-timer" id="workoutTimer">0:00</div>

    <div class="workout-toolbar-meta">
        <input type="text"
               id="workoutName"
               value="<?= h($workout['name'] ?? '') ?>"
               placeholder="<?= h(formatDateNL($workout['date'])) ?>"
               <?= $workout['end_time'] ? 'readonly' : '' ?>>
        <div class="text-dim text-sm" style="margin-top:2px">
            <?= h(formatDateNL($workout['date'], false)) ?>
            <?php if ($workout['end_time']): ?>
            &nbsp;·&nbsp;<span style="color:var(--success)">✓ Afgerond</span>
            <?php endif; ?>
        </div>
    </div>

    <div class="flex gap-1 items-center">
        <?php if (!$workout['end_time']): ?>
        <button class="btn btn-primary" id="btnFinish">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>
            Afronden
        </button>
        <?php else: ?>
        <a href="/webapp/history.php" class="btn btn-secondary">← Geschiedenis</a>
        <?php endif; ?>
        <a href="/webapp/" class="btn btn-secondary btn-sm">← Dashboard</a>
    </div>
</div>

<!-- Live summary -->
<div class="live-summary" id="liveSummary">
    <div class="live-stat">
        <div class="live-stat-val" id="sumExercises">0</div>
        <div class="live-stat-label">Oefeningen</div>
    </div>
    <div class="live-stat">
        <div class="live-stat-val" id="sumSets">0</div>
        <div class="live-stat-label">Sets</div>
    </div>
    <div class="live-stat">
        <div class="live-stat-val" id="sumVolume">0 <?= $weightUnit ?></div>
        <div class="live-stat-label">Volume</div>
    </div>
</div>

<!-- Exercise blocks -->
<div id="exerciseContainer">
<?php foreach ($workout['exercises'] as $ex):
    $isCardio = ($ex['category'] === 'cardio');
    $equip    = $equipmentLabels[$ex['equipment'] ?? 'overig'] ?? '';
    $meta     = array_filter([$ex['muscle_group'] ?? null, $equip ?: null]);
?>
<div class="exercise-block" data-we-id="<?= $ex['id'] ?>" data-category="<?= h($ex['category'] ?? 'kracht') ?>">
    <div class="exercise-header">
        <div class="exercise-header-info">
            <div class="exercise-name"><?= h($ex['name']) ?></div>
            <?php if ($meta): ?>
            <div class="exercise-meta"><?= h(implode(' · ', $meta)) ?></div>
            <?php endif; ?>
        </div>
        <?php if (!$workout['end_time']): ?>
        <button class="btn-icon" onclick="removeExercise(<?= $ex['id'] ?>)" title="Verwijder oefening">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
        </button>
        <?php endif; ?>
    </div>

    <div class="sets-table">
        <div class="sets-header <?= $isCardio ? 'cardio-cols' : '' ?>">
            <span>Set</span>
            <?php if ($isCardio): ?>
            <span>Tijd</span>
            <span>Afstand (<?= $distUnit ?>)</span>
            <?php else: ?>
            <span>Gewicht (<?= $weightUnit ?>)</span>
            <span>Reps</span>
            <span class="col-rpe">RPE</span>
            <?php endif; ?>
            <span></span>
        </div>

        <?php foreach ($ex['sets'] as $set):
            $displayWeight = $set['weight_kg'] !== null
                ? ($unitSystem === 'imperial' ? round($set['weight_kg'] * 2.20462, 1) : $set['weight_kg'])
                : '';
            $displayDist = $set['distance_km'] !== null
                ? ($unitSystem === 'imperial' ? round($set['distance_km'] * 0.621371, 2) : $set['distance_km'])
                : '';
        ?>
        <div class="set-row <?= $isCardio ? 'cardio-cols' : '' ?> <?= $set['is_warmup'] ? 'is-warmup' : '' ?>"
             data-set-id="<?= $set['id'] ?>" data-set-num="<?= $set['set_number'] ?>">
            <div class="set-num">
                <?php if ($set['is_warmup']): ?>
                <span title="Warming-up">W</span>
                <?php else: ?>
                <?= $set['set_number'] ?>
                <?php endif; ?>
            </div>

            <?php if ($isCardio): ?>
            <input class="set-input" type="text" placeholder="mm:ss"
                   value="<?= $set['duration_seconds'] ? formatDuration($set['duration_seconds']) : '' ?>"
                   <?= $workout['end_time'] ? 'readonly' : '' ?>
                   onchange="saveSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this.closest('.set-row'))">
            <input class="set-input" type="number" step="0.01" placeholder="<?= $distUnit ?>"
                   value="<?= h($displayDist) ?>"
                   <?= $workout['end_time'] ? 'readonly' : '' ?>
                   onchange="saveSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this.closest('.set-row'))">
            <?php else: ?>
            <input class="set-input" type="number" step="0.5" placeholder="<?= $weightUnit ?>"
                   value="<?= h($displayWeight) ?>"
                   <?= $workout['end_time'] ? 'readonly' : '' ?>
                   onchange="saveSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this.closest('.set-row'))">
            <input class="set-input" type="number" placeholder="reps"
                   value="<?= $set['reps'] !== null ? h($set['reps']) : '' ?>"
                   <?= $workout['end_time'] ? 'readonly' : '' ?>
                   onchange="saveSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this.closest('.set-row'))">
            <input class="set-input col-rpe" type="number" min="1" max="10" placeholder="RPE"
                   value="<?= $set['rpe'] !== null ? h($set['rpe']) : '' ?>"
                   <?= $workout['end_time'] ? 'readonly' : '' ?>
                   onchange="saveSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this.closest('.set-row'))">
            <?php endif; ?>

            <?php if (!$workout['end_time']): ?>
            <button class="btn-icon" onclick="removeSet(<?= $ex['id'] ?>, <?= $set['set_number'] ?>, this)"
                    title="Verwijder set">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
            <?php else: ?>
            <span></span>
            <?php endif; ?>
        </div>
        <?php endforeach; ?>
    </div>

    <?php if (!$workout['end_time']): ?>
    <div class="set-footer">
        <button class="btn btn-ghost btn-sm" onclick="addSetRow(<?= $ex['id'] ?>, this)">
            + Set toevoegen
        </button>
        <button class="btn btn-sm" style="background:rgba(255,178,63,0.12);color:var(--warning);border:1px solid rgba(255,178,63,0.25)"
                onclick="addSetRow(<?= $ex['id'] ?>, this, true)">
            + Warming-up
        </button>
    </div>
    <?php endif; ?>
</div>
<?php endforeach; ?>
</div>

<?php if (!$workout['end_time']): ?>
<button class="btn btn-ghost btn-block" id="btnAddExercise" style="margin-top:1rem;padding:1rem">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
    Oefening toevoegen
</button>
<?php endif; ?>

<!-- Exercise picker modal -->
<div class="modal-backdrop" id="exerciseModal">
    <div class="modal">
        <div class="modal-header">
            <h3>Oefening kiezen</h3>
            <button class="btn-icon" onclick="closeExerciseModal()">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
        </div>
        <div class="modal-search">
            <div class="search-wrap">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
                <input type="search" class="form-input" id="exerciseSearch"
                       placeholder="Zoek oefening of typ een naam...">
            </div>
        </div>
        <div class="modal-body" id="exerciseResults">
            <div class="empty-state" style="padding:2rem">
                <p>Typ om te zoeken of blader door de lijst.</p>
            </div>
        </div>
    </div>
</div>

<script>
const WORKOUT_ID = <?= $workout['id'] ?>;
const IS_FINISHED = <?= $workout['end_time'] ? 'true' : 'false' ?>;
const START_TIME  = new Date(<?= json_encode($workout['start_time']) ?>);
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
