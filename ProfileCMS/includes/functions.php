<?php
function h(string $s): string {
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function slugify(string $text): string {
    $text = strtolower(trim($text));
    $text = preg_replace('/[^a-z0-9]+/', '-', $text);
    return trim($text, '-');
}

function json_response(mixed $data, int $status = 200): never {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

function json_error(string $message, int $status = 400): never {
    json_response(['error' => $message], $status);
}

function get_articles(string $section, string $status = 'published', int $limit = 20, int $offset = 0): array {
    require_once __DIR__ . '/db.php';
    $stmt = db()->prepare(
        'SELECT id, title, slug, excerpt, section, status, created_at, updated_at
         FROM articles WHERE section = ? AND status = ?
         ORDER BY created_at DESC LIMIT ? OFFSET ?'
    );
    $stmt->execute([$section, $status, $limit, $offset]);
    return $stmt->fetchAll();
}

function get_article_by_slug(string $slug): array|false {
    require_once __DIR__ . '/db.php';
    $stmt = db()->prepare('SELECT * FROM articles WHERE slug = ? AND status = "published"');
    $stmt->execute([$slug]);
    return $stmt->fetch();
}

function time_ago(string $datetime): string {
    $diff = time() - strtotime($datetime);
    return match(true) {
        $diff < 60     => 'just now',
        $diff < 3600   => floor($diff / 60) . 'm ago',
        $diff < 86400  => floor($diff / 3600) . 'h ago',
        $diff < 604800 => floor($diff / 86400) . 'd ago',
        default        => date('d M Y', strtotime($datetime)),
    };
}
