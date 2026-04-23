<?php
$pageTitle  = 'Dashboard';
$activePage = 'dashboard';
require_once __DIR__ . '/includes/header.php';

$pdo = getDB();

// Stats
$totalWorkouts = (int)$pdo->query('SELECT COUNT(*) FROM workouts')->fetchColumn();

$weekStart = date('Y-m-d', strtotime('monday this week'));
$stmtWeek  = $pdo->prepare('SELECT COUNT(*) FROM workouts WHERE date >= ?');
$stmtWeek->execute([$weekStart]);
$thisWeek  = (int)$stmtWeek->fetchColumn();

$stmtVol = $pdo->query('
    SELECT COALESCE(SUM(s.weight_kg * s.reps), 0)
    FROM sets s
    WHERE s.is_warmup = 0
');
$totalVolume = (float)$stmtVol->fetchColumn();

$stmtSets = $pdo->query('SELECT COUNT(*) FROM sets WHERE is_warmup = 0');
$totalSets = (int)$stmtSets->fetchColumn();

// Recent workouts
$stmtRecent = $pdo->query('
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
    LIMIT 7
');
$recentWorkouts = $stmtRecent->fetchAll();

$monthsNL = ['', 'jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
?>

<div class="page-header">
    <div class="page-header-text">
        <h1>Dashboard</h1>
        <p>Welkom terug — blijf consistent!</p>
    </div>
    <a href="/webapp/workout.php" class="btn btn-primary btn-lg">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
            <path d="M12 5v14M5 12h14"/>
        </svg>
        Nieuw workout
    </a>
</div>

<!-- Stats -->
<div class="stats-grid">
    <div class="stat-card">
        <div class="stat-label">Totaal workouts</div>
        <div class="stat-value"><?= $totalWorkouts ?></div>
        <div class="stat-sub">Alle sessies</div>
    </div>
    <div class="stat-card accent">
        <div class="stat-label">Deze week</div>
        <div class="stat-value"><?= $thisWeek ?></div>
        <div class="stat-sub">Vanaf maandag</div>
    </div>
    <div class="stat-card">
        <div class="stat-label">Totaal volume</div>
        <div class="stat-value">
            <?php
            if ($unitSystem === 'imperial') {
                $val = $totalVolume * 2.20462;
                echo $val >= 1000 ? number_format($val / 1000, 1) . 'k' : number_format($val, 0);
                echo ' <small style="font-size:1rem">lbs</small>';
            } else {
                echo $totalVolume >= 1000 ? number_format($totalVolume / 1000, 1) . 'k' : number_format($totalVolume, 0);
                echo ' <small style="font-size:1rem">kg</small>';
            }
            ?>
        </div>
        <div class="stat-sub">Totaal gewicht × reps</div>
    </div>
    <div class="stat-card">
        <div class="stat-label">Totaal sets</div>
        <div class="stat-value"><?= number_format($totalSets) ?></div>
        <div class="stat-sub">Exclusief warming-up</div>
    </div>
</div>

<!-- Recent workouts -->
<div class="section">
    <div class="section-header">
        <span class="section-title">Recente workouts</span>
        <?php if ($totalWorkouts > 7): ?>
        <a href="/webapp/history.php" class="btn btn-sm btn-secondary">Alle workouts</a>
        <?php endif; ?>
    </div>

    <?php if (empty($recentWorkouts)): ?>
    <div class="empty-state">
        <div class="empty-state-icon">🏋️</div>
        <h3>Nog geen workouts</h3>
        <p>Start je eerste workout en begin met het bijhouden van je progressie.</p>
        <a href="/webapp/workout.php" class="btn btn-primary">Start workout</a>
    </div>
    <?php else: ?>
    <div class="workout-list">
        <?php foreach ($recentWorkouts as $w):
            $ts    = strtotime($w['date']);
            $day   = date('j', $ts);
            $month = $monthsNL[(int)date('n', $ts)];
            $name  = $w['name'] ?: formatDateNL($w['date']);
            $vol   = (float)$w['total_volume_kg'];
            $volStr = $unitSystem === 'imperial'
                ? number_format($vol * 2.20462) . ' lbs'
                : number_format($vol) . ' kg';
        ?>
        <a href="/webapp/workout.php?id=<?= $w['id'] ?>" class="workout-item">
            <div class="workout-item-date">
                <div class="day"><?= $day ?></div>
                <div class="month"><?= $month ?></div>
            </div>
            <div class="workout-item-info">
                <div class="workout-item-name"><?= h($name) ?></div>
                <div class="workout-item-meta">
                    <span><?= $w['exercise_count'] ?> oefeningen</span>
                    <span><?= $w['set_count'] ?> sets</span>
                    <?php if ($w['duration_min']): ?>
                    <span><?= $w['duration_min'] ?> min</span>
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
        </a>
        <?php endforeach; ?>
    </div>
    <?php endif; ?>
</div>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
