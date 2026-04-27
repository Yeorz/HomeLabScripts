<?php
/**
 * OAuth 2.0 helpers for Google, Facebook, and Apple Sign In.
 * Pure PHP — no Composer required.
 * PII fields (email, name, oauth_id) are encrypted via crypto.php.
 */

// ── HTTP client ───────────────────────────────────────────────────────────

function oauthPost(string $url, array $params): array {
    $ctx = stream_context_create([
        'http' => [
            'method'        => 'POST',
            'header'        => "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\n",
            'content'       => http_build_query($params),
            'timeout'       => 10,
            'ignore_errors' => true,
        ],
        'ssl' => ['verify_peer' => true, 'verify_peer_name' => true],
    ]);
    $body = @file_get_contents($url, false, $ctx);
    return $body ? (json_decode($body, true) ?? []) : [];
}

function oauthGet(string $url, string $bearer = ''): array {
    $headers = "Accept: application/json\r\n";
    if ($bearer) $headers .= "Authorization: Bearer $bearer\r\n";
    $ctx = stream_context_create([
        'http' => ['method' => 'GET', 'header' => $headers, 'timeout' => 10, 'ignore_errors' => true],
        'ssl'  => ['verify_peer' => true, 'verify_peer_name' => true],
    ]);
    $body = @file_get_contents($url, false, $ctx);
    return $body ? (json_decode($body, true) ?? []) : [];
}

// ── CSRF state ────────────────────────────────────────────────────────────

function oauthStateCreate(string $provider, string $redirect = ''): string {
    $window  = (int)floor(time() / 600);
    $payload = base64url_encode(json_encode(['p' => $provider, 'r' => $redirect, 'w' => $window]));
    $hmac    = base64url_encode(hash_hmac('sha256', $payload, JWT_SECRET, true));
    return "$payload.$hmac";
}

function oauthStateVerify(string $state): ?array {
    $parts = explode('.', $state, 2);
    if (count($parts) !== 2) return null;
    [$payload, $hmac] = $parts;
    $expected = base64url_encode(hash_hmac('sha256', $payload, JWT_SECRET, true));
    if (!hash_equals($expected, $hmac)) return null;
    $data   = json_decode(base64url_decode($payload), true);
    if (!$data) return null;
    $window = (int)floor(time() / 600);
    if (!in_array($data['w'] ?? -1, [$window, $window - 1], true)) return null;
    return $data;
}

function safeRedirectUrl(string $url): string {
    if ($url !== '' && $url[0] === '/' && ($url[1] ?? '') !== '/') return $url;
    return '/webapp/';
}

// ── JWT helpers (Apple) ───────────────────────────────────────────────────

function ecdsaDerToRaw(string $der): string {
    $data = array_values(unpack('C*', $der));
    $idx  = 2;
    $idx++;
    $rLen = $data[$idx++];
    $r    = array_slice($data, $idx, $rLen);
    $idx += $rLen;
    $idx++;
    $sLen = $data[$idx++];
    $s    = array_slice($data, $idx, $sLen);
    while (count($r) > 32) array_shift($r);
    while (count($s) > 32) array_shift($s);
    while (count($r) < 32) array_unshift($r, 0);
    while (count($s) < 32) array_unshift($s, 0);
    return pack('C*', ...[...$r, ...$s]);
}

function jwtDecodePayload(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    return json_decode(base64url_decode($parts[1]), true) ?: null;
}

// ── Apple Sign In ─────────────────────────────────────────────────────────

function appleEnabled(): bool {
    return APPLE_CLIENT_ID !== '' && APPLE_TEAM_ID !== ''
        && APPLE_KEY_ID     !== '' && APPLE_PRIVATE_KEY !== '';
}

function appleClientSecret(): string {
    $header  = base64url_encode(json_encode(['alg' => 'ES256', 'kid' => APPLE_KEY_ID]));
    $payload = base64url_encode(json_encode([
        'iss' => APPLE_TEAM_ID, 'iat' => time(), 'exp' => time() + 600,
        'aud' => 'https://appleid.apple.com', 'sub' => APPLE_CLIENT_ID,
    ]));
    $data = "$header.$payload";
    $pkey = openssl_pkey_get_private(APPLE_PRIVATE_KEY);
    if (!$pkey) return '';
    openssl_sign($data, $derSig, $pkey, OPENSSL_ALGO_SHA256);
    return "$data." . base64url_encode(ecdsaDerToRaw($derSig));
}

function appleAuthUrl(string $state): string {
    return 'https://appleid.apple.com/auth/authorize?' . http_build_query([
        'client_id' => APPLE_CLIENT_ID, 'redirect_uri' => APP_URL . '/webapp/auth/callback.php',
        'response_type' => 'code id_token', 'scope' => 'name email',
        'response_mode' => 'form_post', 'state' => $state,
    ]);
}

function appleExchangeCode(string $code): array {
    return oauthPost('https://appleid.apple.com/auth/token', [
        'client_id' => APPLE_CLIENT_ID, 'client_secret' => appleClientSecret(),
        'code' => $code, 'grant_type' => 'authorization_code',
        'redirect_uri' => APP_URL . '/webapp/auth/callback.php',
    ]);
}

function appleUserFromIdToken(string $idToken): ?array {
    $p = jwtDecodePayload($idToken);
    if (!$p) return null;
    if (($p['iss'] ?? '') !== 'https://appleid.apple.com') return null;
    if (($p['aud'] ?? '') !== APPLE_CLIENT_ID) return null;
    if (($p['exp'] ?? 0) < time()) return null;
    return ['id' => $p['sub'], 'email' => $p['email'] ?? null, 'name' => null];
}

// ── Google OAuth ──────────────────────────────────────────────────────────

function googleEnabled(): bool {
    return GOOGLE_CLIENT_ID !== '' && GOOGLE_CLIENT_SECRET !== '';
}

function googleAuthUrl(string $state): string {
    return 'https://accounts.google.com/o/oauth2/v2/auth?' . http_build_query([
        'client_id' => GOOGLE_CLIENT_ID, 'redirect_uri' => APP_URL . '/webapp/auth/callback.php',
        'response_type' => 'code', 'scope' => 'openid email profile',
        'state' => $state, 'access_type' => 'online',
    ]);
}

function googleExchangeCode(string $code): array {
    return oauthPost('https://oauth2.googleapis.com/token', [
        'code' => $code, 'client_id' => GOOGLE_CLIENT_ID,
        'client_secret' => GOOGLE_CLIENT_SECRET,
        'redirect_uri' => APP_URL . '/webapp/auth/callback.php',
        'grant_type' => 'authorization_code',
    ]);
}

function googleGetUser(string $accessToken): ?array {
    $u = oauthGet('https://www.googleapis.com/oauth2/v3/userinfo', $accessToken);
    if (empty($u['sub'])) return null;
    return ['id' => $u['sub'], 'email' => $u['email'] ?? null, 'name' => $u['name'] ?? null];
}

// ── Facebook OAuth ────────────────────────────────────────────────────────

function facebookEnabled(): bool {
    return FACEBOOK_APP_ID !== '' && FACEBOOK_APP_SECRET !== '';
}

function facebookAuthUrl(string $state): string {
    return 'https://www.facebook.com/v19.0/dialog/oauth?' . http_build_query([
        'client_id' => FACEBOOK_APP_ID, 'redirect_uri' => APP_URL . '/webapp/auth/callback.php',
        'scope' => 'email,public_profile', 'state' => $state,
    ]);
}

function facebookExchangeCode(string $code): array {
    return oauthPost('https://graph.facebook.com/v19.0/oauth/access_token', [
        'client_id' => FACEBOOK_APP_ID, 'client_secret' => FACEBOOK_APP_SECRET,
        'redirect_uri' => APP_URL . '/webapp/auth/callback.php', 'code' => $code,
    ]);
}

function facebookGetUser(string $accessToken): ?array {
    $u = oauthGet('https://graph.facebook.com/me?fields=id,name,email', $accessToken);
    if (empty($u['id'])) return null;
    return ['id' => $u['id'], 'email' => $u['email'] ?? null, 'name' => $u['name'] ?? null];
}

// ── User upsert (with encryption) ─────────────────────────────────────────

function findOrCreateOAuthUser(
    PDO $pdo,
    string $provider,
    string $providerId,
    ?string $email,
    ?string $name
): int {
    // Blind index: HMAC(provider:providerId) — never store plain oauth_id in WHERE clause
    $oauthSearch = searchHash("$provider:$providerId", false);

    // 1. Look up by stable oauth_search blind index
    $stmt = $pdo->prepare('SELECT id FROM users WHERE oauth_search = ?');
    $stmt->execute([$oauthSearch]);
    $userId = $stmt->fetchColumn();
    if ($userId) return (int)$userId;

    // 2. Email match — link this identity to an existing email/password account
    if ($email) {
        $emailHash = searchHash($email);
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email_hash = ?');
        $stmt->execute([$emailHash]);
        $userId = $stmt->fetchColumn();
        if ($userId) {
            $pdo->prepare('
                UPDATE users
                SET oauth_provider = ?, oauth_id = ?, oauth_search = ?,
                    name = COALESCE(name, ?)
                WHERE id = ?
            ')->execute([
                $provider,
                encryptField($providerId),
                $oauthSearch,
                $name ? encryptField($name) : null,
                $userId,
            ]);
            return (int)$userId;
        }
    }

    // 3. Create new OAuth-only user (no password)
    $stmt = $pdo->prepare('
        INSERT INTO users (email, email_hash, name, password, oauth_provider, oauth_id, oauth_search)
        VALUES (?, ?, ?, NULL, ?, ?, ?)
    ');
    $stmt->execute([
        $email ? encryptField($email) : null,
        $email ? searchHash($email)   : null,
        $name  ? encryptField($name)  : null,
        $provider,
        encryptField($providerId),
        $oauthSearch,
    ]);
    return (int)$pdo->lastInsertId();
}
