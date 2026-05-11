<?php
require_once __DIR__ . '/includes/db.php';
require_once __DIR__ . '/includes/functions.php';

// Parse the request URI into route segments
$uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri    = rtrim($uri, '/') ?: '/';
$parts  = explode('/', trim($uri, '/'));
$route  = $parts[0] ?? '';
$slug   = $parts[1] ?? '';

ob_start();

switch ($route) {
    case '':
        // ── Home ──────────────────────────────────────────────────────────────
        $section    = 'home';
        $page_title = setting('site_name');
        $recent_work     = get_articles('work',     'published', 3);
        $recent_personal = get_articles('personal', 'published', 3);
        include __DIR__ . '/pages/home.php';
        break;

    case 'work':
        $section = 'work';
        if ($slug) {
            // ── Single work article ──────────────────────────────────────────
            $article = get_article_by_slug($slug);
            if (!$article || $article['section'] !== 'work') { include __DIR__ . '/pages/404.php'; break; }
            $page_title = $article['title'];
            include __DIR__ . '/pages/article.php';
        } else {
            // ── Work listing ─────────────────────────────────────────────────
            $page_title = 'Work';
            $articles   = get_articles('work', 'published');
            include __DIR__ . '/pages/listing.php';
        }
        break;

    case 'personal':
        $section = 'personal';
        if ($slug) {
            $article = get_article_by_slug($slug);
            if (!$article || $article['section'] !== 'personal') { include __DIR__ . '/pages/404.php'; break; }
            $page_title = $article['title'];
            include __DIR__ . '/pages/article.php';
        } else {
            $page_title = 'Personal';
            $articles   = get_articles('personal', 'published');
            include __DIR__ . '/pages/listing.php';
        }
        break;

    case 'cv':
        $section    = 'cv';
        $page_title = 'CV';
        include __DIR__ . '/pages/cv.php';
        break;

    case 'contact':
        $section    = 'contact';
        $page_title = 'Contact';
        include __DIR__ . '/pages/contact.php';
        break;

    default:
        http_response_code(404);
        $section    = 'default';
        $page_title = 'Not Found';
        include __DIR__ . '/pages/404.php';
}

$content = ob_get_clean();
include __DIR__ . '/templates/layout.php';
