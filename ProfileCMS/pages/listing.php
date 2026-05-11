<?php
// $section, $page_title, $articles are set by index.php
$is_work = $section === 'work';
?>
<div class="page-header page-header--<?= h($section) ?>">
    <?php if ($is_work): ?>
    <div class="matrix-header">
        <canvas id="matrix-canvas"></canvas>
        <div class="matrix-header-content">
            <h1><?= h($page_title) ?></h1>
        </div>
    </div>
    <?php else: ?>
    <div class="container">
        <h1><?= h($page_title) ?></h1>
    </div>
    <?php endif; ?>
</div>

<div class="container listing">
    <?php if (empty($articles)): ?>
    <p class="empty-state">Nothing published here yet.</p>
    <?php else: ?>
    <div class="article-list">
        <?php foreach ($articles as $a): ?>
        <a href="/<?= h($section) ?>/<?= h($a['slug']) ?>" class="article-item article-item--<?= h($section) ?>">
            <div class="article-item-meta">
                <time><?= date('d M Y', strtotime($a['created_at'])) ?></time>
            </div>
            <div class="article-item-body">
                <h2 class="article-item-title"><?= h($a['title']) ?></h2>
                <?php if ($a['excerpt']): ?>
                <p class="article-item-excerpt"><?= h($a['excerpt']) ?></p>
                <?php endif; ?>
            </div>
            <span class="article-item-arrow">&rarr;</span>
        </a>
        <?php endforeach; ?>
    </div>
    <?php endif; ?>
</div>

<?php if ($is_work): ?>
<script src="/assets/js/matrix.js"></script>
<?php endif; ?>
