<?php
require_once dirname(__DIR__) . '/includes/db.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/oauth.php';

/**
 * OAuth callback — handles redirects from Google and Facebook (GET)
 * and form-post from Apple (POST).
 *
 * All three providers encode the provider name in the `state` parameter
 * so a single callback URL can serve all of them.
 */

// ── Read parameters (GET for Google/FB, POST for Apple) ──────────────────
$state = trim($_POST['state'] ?? $_GET['state'] ?? '');
$code  = trim($_POST['code']  ?? $_GET['code']  ?? '');
$error = $_GET['error'] ?? $_POST['error'] ?? '';

function failWith(string $msg): never {
    // Redirect to login with a generic error message
    header('Location: /webapp/auth/login.php?error=' . urlencode($msg));
    exit;
}

if ($error) failWith('Sign-in was cancelled or denied.');
if (!$state) failWith('Missing state parameter.');

// ── Verify state (CSRF protection) ───────────────────────────────────────
$stateData = oauthStateVerify($state);
if (!$stateData) failWith('Invalid or expired state. Please try again.');

$provider = $stateData['p'] ?? '';
$redirect = safeRedirectUrl($stateData['r'] ?? '');

if (!in_array($provider, ['google', 'facebook', 'apple'], true)) {
    failWith('Unknown provider.');
}

if (!$code) failWith('No authorisation code received.');

// ── Exchange code and get user info ───────────────────────────────────────
$providerUser = null;

try {
    switch ($provider) {

        case 'google':
            $tokens = googleExchangeCode($code);
            if (empty($tokens['access_token'])) failWith('Google token exchange failed.');
            $providerUser = googleGetUser($tokens['access_token']);
            break;

        case 'facebook':
            $tokens = facebookExchangeCode($code);
            if (empty($tokens['access_token'])) failWith('Facebook token exchange failed.');
            $providerUser = facebookGetUser($tokens['access_token']);
            break;

        case 'apple':
            $tokens = appleExchangeCode($code);
            if (empty($tokens['id_token'])) failWith('Apple token exchange failed.');
            $providerUser = appleUserFromIdToken($tokens['id_token']);

            // Apple sends the user's name only on the very first authorisation.
            // It arrives as a JSON string in the `user` POST field.
            if ($providerUser && isset($_POST['user'])) {
                $appleUserData = json_decode($_POST['user'], true);
                if (is_array($appleUserData)) {
                    $firstName = $appleUserData['name']['firstName'] ?? '';
                    $lastName  = $appleUserData['name']['lastName']  ?? '';
                    $fullName  = trim("$firstName $lastName");
                    if ($fullName !== '') {
                        $providerUser['name'] = $fullName;
                    }
                    // Apple may also surface email here on first sign-in
                    if (empty($providerUser['email']) && !empty($appleUserData['email'])) {
                        $providerUser['email'] = $appleUserData['email'];
                    }
                }
            }
            break;
    }
} catch (Throwable $e) {
    error_log("OAuth callback error ($provider): " . $e->getMessage());
    failWith('An error occurred during sign-in. Please try again.');
}

if (!$providerUser || empty($providerUser['id'])) {
    failWith('Could not retrieve user information from ' . ucfirst($provider) . '.');
}

// ── Upsert user in our database ───────────────────────────────────────────
try {
    $pdo    = getDB();
    $userId = findOrCreateOAuthUser(
        $pdo,
        $provider,
        (string)$providerUser['id'],
        $providerUser['email']  ?? null,
        $providerUser['name']   ?? null
    );
} catch (Throwable $e) {
    error_log("OAuth user upsert error: " . $e->getMessage());
    failWith('Could not create your account. Please try again.');
}

// ── Issue session token and redirect ─────────────────────────────────────
setAuthCookie(issueToken($userId));
header('Location: ' . ($redirect ?: '/webapp/'));
exit;
