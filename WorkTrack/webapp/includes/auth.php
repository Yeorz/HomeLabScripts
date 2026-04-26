<?php
/**
 * JWT authentication helpers — no Composer required.
 * HS256 implementation using PHP's built-in hash_hmac.
 */

function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function base64url_decode(string $data): string {
    $pad  = (4 - strlen($data) % 4) % 4;
    return base64_decode(strtr($data, '-_', '+/') . str_repeat('=', $pad));
}

function jwtCreate(array $payload, string $secret): string {
    $header  = base64url_encode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload = base64url_encode(json_encode($payload));
    $sig     = base64url_encode(hash_hmac('sha256', "$header.$payload", $secret, true));
    return "$header.$payload.$sig";
}

function jwtVerify(string $token, string $secret): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$header, $payload, $sig] = $parts;
    $expected = base64url_encode(hash_hmac('sha256', "$header.$payload", $secret, true));
    if (!hash_equals($expected, $sig)) return null;
    $data = json_decode(base64url_decode($payload), true);
    if (!$data || ($data['exp'] ?? 0) < time()) return null;
    return $data;
}

function issueToken(int $userId): string {
    return jwtCreate([
        'id'  => $userId,
        'iat' => time(),
        'exp' => time() + 86400, // 24 hours
    ], JWT_SECRET);
}

function getAuthUser(): ?array {
    // Bearer header — used by mobile and watch apps
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? apache_request_headers()['Authorization'] ?? '';
    if (preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
        return jwtVerify($m[1], JWT_SECRET);
    }
    // httpOnly cookie — used by web interface
    $cookie = $_COOKIE['token'] ?? '';
    if ($cookie) {
        return jwtVerify($cookie, JWT_SECRET);
    }
    return null;
}

function requireAuth(): array {
    $user = getAuthUser();
    if (!$user) {
        http_response_code(401);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['error' => 'Authentication required']);
        exit;
    }
    return $user;
}

function setCORSHeaders(): void {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    // Allow any origin for the mobile apps; tighten in production via allowed-origins config
    if ($origin) {
        header("Access-Control-Allow-Origin: $origin");
        header("Access-Control-Allow-Credentials: true");
    } else {
        header("Access-Control-Allow-Origin: *");
    }
    header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token");
    header("Access-Control-Max-Age: 86400");

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

// Stateless CSRF token valid for the current and previous hour window
function csrfGenerate(): string {
    $window = (string)floor(time() / 3600);
    return base64url_encode(hash_hmac('sha256', "csrf-$window", JWT_SECRET, true));
}

function csrfVerify(string $token): bool {
    $current = floor(time() / 3600);
    foreach ([$current, $current - 1] as $window) {
        $expected = base64url_encode(hash_hmac('sha256', "csrf-$window", JWT_SECRET, true));
        if (hash_equals($expected, $token)) return true;
    }
    return false;
}
