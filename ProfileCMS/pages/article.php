<div class="container article-page">
    <nav class="breadcrumb">
        <a href="/<?= h($article['section']) ?>"><?= ucfirst(h($article['section'])) ?></a>
        <span>/</span>
        <span><?= h($article['title']) ?></span>
    </nav>

    <article class="article article--<?= h($article['section']) ?>">
        <header class="article-header">
            <h1 class="article-title"><?= h($article['title']) ?></h1>
            <time class="article-date" datetime="<?= h($article['created_at']) ?>">
                <?= date('d F Y', strtotime($article['created_at'])) ?>
            </time>
        </header>

        <div class="article-content ql-editor">
            <?= $article['content'] ?>
        </div>
    </article>

    <a href="/<?= h($article['section']) ?>" class="back-link">&larr; Back to <?= ucfirst(h($article['section'])) ?></a>
</div>
