<?php
// Copy this file to config.php and fill in your values.

// ── Database ──────────────────────────────────────────────────────────────
define('DB_HOST',    'localhost');
define('DB_PORT',    '3306');
define('DB_NAME',    'worktrack');
define('DB_USER',    'worktrack_user');
define('DB_PASS',    'change_this_password');
define('DB_CHARSET', 'utf8mb4');

// ── App ───────────────────────────────────────────────────────────────────
// Full public URL of the app root — NO trailing slash.
// Used to build OAuth redirect URIs.
define('APP_URL', 'http://localhost:8080');

// JWT secret — signs all auth tokens for mobile/watch and web sessions.
// Generate: php -r "echo bin2hex(random_bytes(32));"
define('JWT_SECRET', 'CHANGE_THIS_generate_with_php_r_echo_bin2hex_random_bytes_32');

// Allowed browser origins for the CORS policy.
define('ALLOWED_ORIGINS', [
    'http://localhost:8080',
    'http://localhost:5173',
    'http://localhost:3000',
    // 'https://your-production-domain.com',
]);

// ── Google OAuth ──────────────────────────────────────────────────────────
// Create at https://console.cloud.google.com → APIs & Services → Credentials
// Authorized redirect URI: APP_URL/webapp/auth/callback.php
define('GOOGLE_CLIENT_ID',     '');
define('GOOGLE_CLIENT_SECRET', '');

// ── Facebook OAuth ────────────────────────────────────────────────────────
// Create at https://developers.facebook.com → My Apps → Add App
// Valid OAuth redirect URI: APP_URL/webapp/auth/callback.php
define('FACEBOOK_APP_ID',     '');
define('FACEBOOK_APP_SECRET', '');

// ── Apple Sign In ─────────────────────────────────────────────────────────
// Set up at https://developer.apple.com → Certificates, Identifiers & Profiles
// 1. Create an App ID with Sign In with Apple enabled
// 2. Create a Services ID (this is your CLIENT_ID, e.g. com.example.worktrack.web)
// 3. Generate a Sign In with Apple private key (.p8 file)
// Return URLs: APP_URL/webapp/auth/callback.php
define('APPLE_CLIENT_ID',  '');           // Services ID
define('APPLE_TEAM_ID',    '');           // 10-char team ID from Apple Developer
define('APPLE_KEY_ID',     '');           // Key ID from the .p8 key
define('APPLE_PRIVATE_KEY', <<<'PEM'
-----BEGIN PRIVATE KEY-----
paste_your_p8_key_contents_here
-----END PRIVATE KEY-----
PEM);
