<?php
/**
 * JWT authentication helpers — no Composer required.
 * HS256 implementation using PHP's built-in hash_hmac.
 */

function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function base64url_decode(string $data): string {
    $pad = (4 - strlen($data) % 4) % 4;
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
        'exp' => time() + 86400,
    ], JWT_SECRET);
}

function getAuthUser(): ?array {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? apache_request_headers()['Authorization'] ?? '';
    if (preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
        return jwtVerify($m[1], JWT_SECRET);
    }
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

/**
 * Sets the auth cookie with correct security flags.
 * The `secure` flag is enabled automatically when the request is over HTTPS.
 */
function setAuthCookie(string $token): void {
    $isSecure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
             || (int)($_SERVER['SERVER_PORT'] ?? 80) === 443;
    setcookie('token', $token, [
        'expires'  => time() + 86400,
        'path'     => '/',
        'httponly' => true,
        'secure'   => $isSecure,
        'samesite' => 'Strict',
    ]);
}

/**
 * Clears the auth cookie.
 */
function clearAuthCookie(): void {
    $isSecure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
             || (int)($_SERVER['SERVER_PORT'] ?? 80) === 443;
    setcookie('token', '', [
        'expires'  => time() - 3600,
        'path'     => '/',
        'httponly' => true,
        'secure'   => $isSecure,
        'samesite' => 'Strict',
    ]);
}

/**
 * CORS — only allow origins explicitly listed in ALLOWED_ORIGINS config.
 * Native mobile/watch apps send no Origin header, so they bypass CORS
 * entirely (which is correct; CORS is a browser mechanism only).
 *
 * Fix for: reflected-origin CORS + Allow-Credentials vulnerability.
 */
function setCORSHeaders(): void {
    $origin  = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = defined('ALLOWED_ORIGINS') ? (array)ALLOWED_ORIGINS : [];

    if ($origin !== '') {
        if (in_array($origin, $allowed, true)) {
            header("Access-Control-Allow-Origin: $origin");
            header("Access-Control-Allow-Credentials: true");
            header("Vary: Origin");
        }
        // Unknown origin → no ACAO header; the browser will block the request.
    }
    // No Origin header (native apps) → no CORS header needed.

    header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token");
    header("Access-Control-Max-Age: 86400");

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

// ── CSRF ──────────────────────────────────────────────────────────────────

/**
 * Stateless CSRF token: HMAC of current one-hour window.
 * Valid for the current and previous window (~2 hours max lifetime).
 */
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

/**
 * Enforce CSRF for browser requests; exempt Bearer-authenticated mobile calls.
 * Mobile/watch apps use Bearer tokens which are immune to CSRF by design,
 * so they must not be blocked here.
 */
function requireCsrfOrBearer(): void {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? apache_request_headers()['Authorization'] ?? '';
    if (preg_match('/^Bearer\s+/i', $authHeader)) {
        return; // Mobile / Watch — Bearer is CSRF-safe
    }
    $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? $_POST['_csrf'] ?? '';
    if ($token === '' || !csrfVerify($token)) {
        jsonError('CSRF token missing or invalid', 403);
    }
}

// ── Ownership ─────────────────────────────────────────────────────────────

/**
 * Verify that the requesting client may access the given workout.
 *
 * Rules:
 *  - Authenticated user  → must own the workout (user_id match).
 *  - Unauthenticated     → may only access workouts with user_id = NULL
 *                          (web-UI-created workouts in single-user mode).
 */
function assertWorkoutAccess(PDO $pdo, int $workoutId): void {
    $stmt = $pdo->prepare('SELECT user_id FROM workouts WHERE id = ?');
    $stmt->execute([$workoutId]);
    $row = $stmt->fetch();
    if (!$row) jsonError('Workout not found', 404);

    $user = getAuthUser();
    if ($user) {
        if ((int)$row['user_id'] !== (int)$user['id']) {
            jsonError('Access denied', 403);
        }
    } else {
        if ($row['user_id'] !== null) {
            jsonError('Access denied', 403);
        }
    }
}
