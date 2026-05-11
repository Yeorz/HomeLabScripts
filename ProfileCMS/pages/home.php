<section class="hero">
    <div class="hero-inner">
        <h1 class="hero-name"><?= h(setting('owner_name')) ?></h1>
        <p class="hero-tagline"><?= h(setting('site_tagline')) ?></p>
        <div class="hero-links">
            <a href="/work" class="btn btn-work">Work</a>
            <a href="/personal" class="btn btn-personal">Personal</a>
            <a href="/cv" class="btn btn-ghost">CV</a>
            <a href="/contact" class="btn btn-ghost">Contact</a>
        </div>
    </div>
</section>

<?php if ($recent_work): ?>
<section class="home-section">
    <div class="container">
        <h2 class="section-heading section-heading--work">Recent Work</h2>
        <div class="card-grid">
            <?php foreach ($recent_work as $a): ?>
            <a href="/work/<?= h($a['slug']) ?>" class="card card--work">
                <h3 class="card-title"><?= h($a['title']) ?></h3>
                <?php if ($a['excerpt']): ?>
                <p class="card-excerpt"><?= h($a['excerpt']) ?></p>
                <?php endif; ?>
                <span class="card-date"><?= time_ago($a['created_at']) ?></span>
            </a>
            <?php endforeach; ?>
        </div>
        <a href="/work" class="view-all">All work &rarr;</a>
    </div>
</section>
<?php endif; ?>

<?php if ($recent_personal): ?>
<section class="home-section">
    <div class="container">
        <h2 class="section-heading section-heading--personal">Personal</h2>
        <div class="card-grid">
            <?php foreach ($recent_personal as $a): ?>
            <a href="/personal/<?= h($a['slug']) ?>" class="card card--personal">
                <h3 class="card-title"><?= h($a['title']) ?></h3>
                <?php if ($a['excerpt']): ?>
                <p class="card-excerpt"><?= h($a['excerpt']) ?></p>
                <?php endif; ?>
                <span class="card-date"><?= time_ago($a['created_at']) ?></span>
            </a>
            <?php endforeach; ?>
        </div>
        <a href="/personal" class="view-all">All posts &rarr;</a>
    </div>
</section>
<?php endif; ?>
