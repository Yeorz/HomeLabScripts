<?php
$pageTitle  = 'History';
$activePage = 'history';
require_once __DIR__ . '/includes/header.php';

$pdo = getDB();

$stmt = $pdo->query('
    SELECT w.*,
           COUNT(DISTINCT we.id)                           AS exercise_count,
           COUNT(s.id)                                     AS set_count,
           COALESCE(SUM(s.weight_kg * s.reps), 0)          AS total_volume_kg,
           TIMESTAMPDIFF(MINUTE, w.start_time, w.end_time) AS duration_min
    FROM workouts w
    LEFT JOIN workout_exercises we ON we.workout_id = w.id
    LEFT JOIN sets s ON s.workout_exercise_id = we.id AND s.is_warmup = 0
    GROUP BY w.id
    ORDER BY w.date DESC, w.start_time DESC
');
$allWorkouts = decryptRows($stmt->fetchAll(), ['name', 'notes']);

$months      = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'];
$monthsShort = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

$grouped = [];
foreach ($allWorkouts as $w) {
    $key = date('Y-m', strtotime($w['date']));
    $grouped[$key][] = $w;
}
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>History</h1>
        <p><?= count($allWorkouts) ?> workouts logged</p>
    </div>
    <a href="/webapp/workout.php" class="btn btn-primary">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
        New workout
    </a>
</div>

<?php if (empty($allWorkouts)): ?>
<div class="empty-state">
    <div class="empty-state-icon">📋</div>
    <h3>No workouts yet</h3>
    <p>Your workout history will appear here once you log your first session.</p>
    <a href="/webapp/workout.php" class="btn btn-primary">Start first workout</a>
</div>
<?php else: ?>

<?php foreach ($grouped as $key => $workouts):
    [$year, $mon] = explode('-', $key);
    $label = $months[(int)$mon] . ' ' . $year;
?>
<div class="section">
    <div class="section-header">
        <span class="section-title"><?= h($label) ?></span>
        <span class="badge badge-muted"><?= count($workouts) ?> workouts</span>
    </div>

    <div class="workout-list">
        <?php foreach ($workouts as $w):
            $ts     = strtotime($w['date']);
            $day    = date('j', $ts);
            $month  = $monthsShort[(int)date('n', $ts)];
            $name   = $w['name'] ?: formatDate($w['date']);
            $vol    = (float)$w['total_volume_kg'];
            $volStr = $unitSystem === 'imperial'
                ? number_format($vol * 2.20462) . ' lbs'
                : number_format($vol) . ' kg';
        ?>
        <div class="workout-item" style="cursor:pointer;flex-direction:column;align-items:stretch"
             onclick="toggleDetail(this, <?= $w['id'] ?>)">
            <div style="display:flex;align-items:center;gap:1.25rem">
                <div class="workout-item-date">
                    <div class="day"><?= $day ?></div>
                    <div class="month"><?= $month ?></div>
                </div>
                <div class="workout-item-info">
                    <div class="workout-item-name"><?= h($name) ?></div>
                    <div class="workout-item-meta">
                        <span><?= $w['exercise_count'] ?> exercises</span>
                        <span><?= $w['set_count'] ?> sets</span>
                        <?php if ($w['duration_min']): ?>
                        <span><?= $w['duration_min'] ?> min</span>
                        <?php endif; ?>
                        <?php if (!$w['end_time']): ?>
                        <span class="badge badge-danger">Incomplete</span>
                        <?php endif; ?>
                    </div>
                </div>
                <div class="workout-item-stats">
                    <div class="workout-stat">
                        <div class="workout-stat-val"><?= $volStr ?></div>
                        <div class="workout-stat-label">Volume</div>
                    </div>
                    <div class="workout-stat">
                        <div class="workout-stat-val"><?= $w['set_count'] ?></div>
                        <div class="workout-stat-label">Sets</div>
                    </div>
                </div>
                <div style="display:flex;gap:0.5rem;flex-shrink:0">
                    <a href="/webapp/workout.php?id=<?= $w['id'] ?>"
                       class="btn btn-sm btn-secondary"
                       onclick="event.stopPropagation()">Edit</a>
                    <button class="btn-icon"
                            onclick="event.stopPropagation();deleteWorkout(<?= $w['id'] ?>, this)"
                            title="Delete workout">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/></svg>
                    </button>
                </div>
            </div>
            <div class="workout-detail" id="detail-<?= $w['id'] ?>">
                <div class="loading text-muted text-sm" style="padding:0.5rem">Loading...</div>
            </div>
        </div>
        <?php endforeach; ?>
    </div>
</div>
<?php endforeach; ?>
<?php endif; ?>

<script>
async function toggleDetail(row, workoutId) {
    const detail = document.getElementById('detail-' + workoutId);
    if (detail.classList.contains('open')) {
        detail.classList.remove('open');
        return;
    }
    detail.classList.add('open');
    if (!detail.dataset.loaded) {
        try {
            const res  = await fetch('/webapp/api/workouts.php?action=get&id=' + workoutId);
            const data = await res.json();
            detail.innerHTML = renderDetail(data);
            detail.dataset.loaded = '1';
        } catch {
            detail.innerHTML = '<p class="text-muted text-sm">Could not load details.</p>';
        }
    }
}

function renderDetail(data) {
    if (!data.exercises || !data.exercises.length) {
        return '<p class="text-muted text-sm">No exercises logged.</p>';
    }
    const unit = UNIT_SYSTEM;
    let html = '';
    for (const ex of data.exercises) {
        html += `<div class="detail-exercise">
            <div class="detail-exercise-name">${escHtml(ex.name)}</div>
            <table class="detail-sets-table">
                <thead><tr>
                    <th>Set</th>
                    ${ex.category === 'cardio'
                        ? '<th>Time</th><th>Distance</th>'
                        : '<th>Weight</th><th>Reps</th>'}
                </tr></thead>
                <tbody>`;
        for (const s of ex.sets) {
            const setLabel = s.is_warmup ? 'W' : s.set_number;
            if (ex.category === 'cardio') {
                const dur  = s.duration_seconds ? formatDur(s.duration_seconds) : '—';
                const dist = s.distance_km != null
                    ? (unit === 'imperial' ? (s.distance_km * 0.621371).toFixed(2) + ' mi' : s.distance_km + ' km')
                    : '—';
                html += `<tr><td>${setLabel}</td><td>${dur}</td><td>${dist}</td></tr>`;
            } else {
                const w = s.weight_kg != null
                    ? (unit === 'imperial' ? Math.round(s.weight_kg * 2.20462 * 10) / 10 + ' lbs' : s.weight_kg + ' kg')
                    : '—';
                html += `<tr><td>${setLabel}</td><td>${w}</td><td>${s.reps ?? '—'}</td></tr>`;
            }
        }
        html += `</tbody></table></div>`;
    }
    return html;
}

async function deleteWorkout(id, btn) {
    if (!confirm('Delete this workout? This cannot be undone.')) return;
    btn.disabled = true;
    await fetch('/webapp/api/workouts.php?action=delete', {
        method: 'POST',
        headers: {'Content-Type': 'application/json', 'X-CSRF-Token': CSRF_TOKEN},
        body: JSON.stringify({action: 'delete', id})
    });
    btn.closest('.workout-item').remove();
    showToast('Workout deleted', 'info');
}
</script>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
