<?php
/**
 * WorkTrack — Browser Installer
 *
 * Upload the full project directory, then visit /webapp/install.php.
 * The file self-deletes after successful installation.
 */
declare(strict_types=1);
error_reporting(0);          // never show errors to the browser during install

// ── Helpers ───────────────────────────────────────────────────────────────
function gen_key(): string   { return bin2hex(random_bytes(32)); }
function h(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function q(string $v): string { return var_export($v, true); }   // safe for writing to PHP file

// ── Guard: already installed? ─────────────────────────────────────────────
$configPath = __DIR__ . '/config.php';
function is_installed(): bool {
    global $configPath;
    if (!file_exists($configPath)) return false;
    $c = file_get_contents($configPath);
    return str_contains($c, "define('DB_HOST'")
        && !str_contains($c, 'CHANGE_THIS');
}
if (is_installed() && !isset($_GET['force'])) {
    http_response_code(403);
    die('<b>WorkTrack is already installed.</b> Delete <code>install.php</code> or add <code>?force=1</code> to reconfigure.');
}

// ── Session ───────────────────────────────────────────────────────────────
session_start();
if (empty($_SESSION['csrf'])) {
    $_SESSION['csrf'] = bin2hex(random_bytes(16));
}
$csrf = $_SESSION['csrf'];

function csrf_ok(): bool {
    return isset($_POST['_csrf']) && hash_equals($_SESSION['csrf'], $_POST['_csrf']);
}

// ── Current step (determined early — needed before redirect logic) ─────────
$step = max(1, min(6, (int)($_GET['step'] ?? 1)));

// ── Pre-output redirects (must happen before any echo) ───────────────────

// Regenerate keys (step 3)
if ($step === 3 && isset($_GET['regen'])) {
    $_SESSION['install']['app'] = array_merge(
        $_SESSION['install']['app'] ?? [],
        ['jwt' => gen_key(), 'enckey' => gen_key(), 'srchkey' => gen_key()]
    );
    header('Location: install.php?step=3');
    exit;
}

// Self-delete (step 6)
if ($step === 6 && isset($_GET['delete'])) {
    $appUrl = $_SESSION['install']['app']['url'] ?? '/webapp';
    session_destroy();
    @unlink(__FILE__);
    header('Location: ' . $appUrl . '/webapp/');
    exit;
}

// ── Config writer ─────────────────────────────────────────────────────────
function render_config(array $d, array $a, array $o): string {
    $lines = [
        '<?php',
        "define('DB_HOST',    " . q($d['host']) . ');',
        "define('DB_PORT',    " . q($d['port']) . ');',
        "define('DB_NAME',    " . q($d['name']) . ');',
        "define('DB_USER',    " . q($d['user']) . ');',
        "define('DB_PASS',    " . q($d['pass']) . ');',
        "define('DB_CHARSET', 'utf8mb4');",
        '',
        "define('APP_URL', " . q($a['url']) . ');',
        '',
        "define('JWT_SECRET',         " . q($a['jwt'])     . ');',
        "define('APP_ENCRYPTION_KEY', " . q($a['enckey'])  . ');',
        "define('APP_SEARCH_KEY',     " . q($a['srchkey']) . ');',
        '',
        "define('ALLOWED_ORIGINS', [" . q($a['url']) . ']);',
        '',
        "define('GOOGLE_CLIENT_ID',     " . q($o['google_id']     ?? '') . ');',
        "define('GOOGLE_CLIENT_SECRET', " . q($o['google_secret'] ?? '') . ');',
        '',
        "define('FACEBOOK_APP_ID',     " . q($o['fb_id']     ?? '') . ');',
        "define('FACEBOOK_APP_SECRET', " . q($o['fb_secret'] ?? '') . ');',
        '',
        "define('APPLE_CLIENT_ID',   " . q($o['apple_id']     ?? '') . ');',
        "define('APPLE_TEAM_ID',     " . q($o['apple_team']   ?? '') . ');',
        "define('APPLE_KEY_ID',      " . q($o['apple_key_id'] ?? '') . ');',
        "define('APPLE_PRIVATE_KEY', " . q($o['apple_pem']    ?? '') . ');',
    ];
    return implode(PHP_EOL, $lines) . PHP_EOL;
}

// ── Requirements checker ──────────────────────────────────────────────────
function check_requirements(): array {
    $ok = [];
    $ok[] = ['PHP ≥ 8.1',         version_compare(PHP_VERSION, '8.1.0', '>='), PHP_VERSION];
    foreach (['pdo', 'pdo_mysql', 'openssl', 'mbstring', 'json', 'hash'] as $ext) {
        $ok[] = ["php-{$ext}", extension_loaded($ext), ''];
    }
    $ok[] = ['config.php writable', is_writable(__DIR__),          ''];
    $ok[] = ['setup.sql present',   file_exists(__DIR__ . '/setup.sql'), ''];
    $ok[] = ['includes/ readable',  is_dir(__DIR__ . '/includes'), ''];
    return $ok;
}

// ── Run setup.sql ─────────────────────────────────────────────────────────
function run_setup_sql(PDO $pdo): void {
    $sql = file_get_contents(__DIR__ . '/setup.sql');
    if ($sql === false) throw new RuntimeException('Cannot read setup.sql');

    // Split on statement-ending semicolons; skip comment-only blocks
    $statements = array_filter(
        array_map('trim', explode(';', $sql)),
        fn($s) => $s !== '' && !preg_match('/^\s*--/', $s)
    );
    foreach ($statements as $stmt) {
        $pdo->exec($stmt);
    }
}

// ── POST handler ──────────────────────────────────────────────────────────
$errors = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && csrf_ok()) {
    switch ($step) {

        case 2: {
            $db = [
                'host' => trim($_POST['db_host'] ?? 'localhost'),
                'port' => trim($_POST['db_port'] ?? '3306'),
                'name' => trim($_POST['db_name'] ?? 'worktrack'),
                'user' => trim($_POST['db_user'] ?? ''),
                'pass' => (string)($_POST['db_pass'] ?? ''),
            ];
            // Test full DSN (database may not exist yet)
            try {
                $dsn = "mysql:host={$db['host']};port={$db['port']};dbname={$db['name']};charset=utf8mb4";
                new PDO($dsn, $db['user'], $db['pass'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
                $_SESSION['install']['db'] = $db;
                header('Location: install.php?step=3'); exit;
            } catch (PDOException) {
                // DB might not exist yet — try without dbname
                try {
                    $dsn2 = "mysql:host={$db['host']};port={$db['port']};charset=utf8mb4";
                    $pdo  = new PDO($dsn2, $db['user'], $db['pass'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
                    $pdo->exec("CREATE DATABASE IF NOT EXISTS `{$db['name']}`
                        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
                    $_SESSION['install']['db'] = $db;
                    header('Location: install.php?step=3'); exit;
                } catch (PDOException $e) {
                    $errors[] = 'Connection failed: ' . $e->getMessage();
                }
            }
            break;
        }

        case 3: {
            $_SESSION['install']['app'] = [
                'url'     => rtrim((string)($_POST['app_url'] ?? ''), '/'),
                'jwt'     => (string)($_POST['jwt']     ?? '') ?: gen_key(),
                'enckey'  => (string)($_POST['enckey']  ?? '') ?: gen_key(),
                'srchkey' => (string)($_POST['srchkey'] ?? '') ?: gen_key(),
            ];
            header('Location: install.php?step=4'); exit;
        }

        case 4: {
            $_SESSION['install']['oauth'] = [
                'google_id'     => trim((string)($_POST['google_id']     ?? '')),
                'google_secret' => trim((string)($_POST['google_secret'] ?? '')),
                'fb_id'         => trim((string)($_POST['fb_id']         ?? '')),
                'fb_secret'     => trim((string)($_POST['fb_secret']     ?? '')),
                'apple_id'      => trim((string)($_POST['apple_id']      ?? '')),
                'apple_team'    => trim((string)($_POST['apple_team']    ?? '')),
                'apple_key_id'  => trim((string)($_POST['apple_key_id']  ?? '')),
                'apple_pem'     => trim((string)($_POST['apple_pem']     ?? '')),
            ];
            header('Location: install.php?step=5'); exit;
        }

        case 5: {
            $d = $_SESSION['install']['db']    ?? [];
            $a = $_SESSION['install']['app']   ?? [];
            $o = $_SESSION['install']['oauth'] ?? [];

            if (empty($d) || empty($a)) {
                $errors[] = 'Session data lost — please start from step 1.';
                break;
            }

            try {
                // Connect (DB was created in step 2)
                $dsn = "mysql:host={$d['host']};port={$d['port']};dbname={$d['name']};charset=utf8mb4";
                $pdo = new PDO($dsn, $d['user'], $d['pass'],
                    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

                // Schema + seed data
                run_setup_sql($pdo);

                // Write config.php
                $rendered = render_config($d, $a, $o);
                if (file_put_contents($configPath, $rendered) === false) {
                    throw new RuntimeException(
                        "Cannot write config.php — check that the web server user has write " .
                        "permission on " . dirname($configPath)
                    );
                }

                header('Location: install.php?step=6'); exit;

            } catch (Throwable $e) {
                $errors[] = $e->getMessage();
            }
            break;
        }
    }
}

// ── Data for view ─────────────────────────────────────────────────────────
$req    = ($step === 1) ? check_requirements() : [];
$allOk  = !in_array(false, array_column($req, 1), true);

// Auto-seed keys for step 3 on first visit
if ($step === 3 && empty($_SESSION['install']['app']['jwt'])) {
    $_SESSION['install']['app'] = array_merge(
        $_SESSION['install']['app'] ?? [],
        ['jwt' => gen_key(), 'enckey' => gen_key(), 'srchkey' => gen_key()]
    );
}

// Auto-detect URL
$proto       = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$detectedUrl = $proto . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');

$stepNames = ['Requirements', 'Database', 'Configuration', 'OAuth', 'Install', 'Done'];

// ── HTML ──────────────────────────────────────────────────────────────────
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>WorkTrack Installer — Step <?= $step ?></title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0c0c14;--surface:#0e1119;--card:#141720;--border:rgba(255,255,255,.08);
  --primary:#7c5cfc;--primary-dim:rgba(124,92,252,.15);
  --accent:#00d4a3;--danger:#ff4560;--warn:#ffb23f;
  --text:#f0f4ff;--muted:#8892aa;--dim:#4d566e;--r:10px;
}
body{font-family:system-ui,-apple-system,sans-serif;background:var(--bg);
  color:var(--text);min-height:100vh;display:flex;flex-direction:column;
  align-items:center;padding:2.5rem 1rem}

/* Brand */
.brand{display:flex;align-items:center;gap:.5rem;font-size:1.1rem;
  font-weight:800;margin-bottom:1.75rem}
.brand svg{color:var(--primary)}

/* Card */
.card{background:var(--card);border:1px solid var(--border);border-radius:18px;
  padding:2rem;width:100%;max-width:600px;box-shadow:0 8px 48px rgba(0,0,0,.6)}

/* Progress */
.prog{display:flex;gap:5px;margin-bottom:.75rem}
.ps{flex:1;height:4px;border-radius:99px;background:var(--border);transition:background .3s}
.ps.done{background:var(--accent)}
.ps.active{background:var(--primary)}
.step-lbl{font-size:.72rem;color:var(--muted);letter-spacing:.07em;
  text-transform:uppercase;margin-bottom:1.75rem}

h1{font-size:1.25rem;font-weight:700;margin-bottom:1.25rem}
p.sub{color:var(--muted);font-size:.87rem;margin-bottom:1.25rem;line-height:1.6}

/* Requirement rows */
.req-row{display:flex;align-items:center;gap:.75rem;padding:.5rem 0;
  border-bottom:1px solid var(--border);font-size:.88rem}
.req-row:last-child{border:none}
.dot{width:22px;height:22px;border-radius:50%;display:flex;align-items:center;
  justify-content:center;font-size:.78rem;font-weight:700;flex-shrink:0}
.dot.ok{background:rgba(0,212,163,.15);color:var(--accent)}
.dot.fail{background:rgba(255,69,96,.15);color:var(--danger)}
.dot.skip{background:rgba(255,178,63,.15);color:var(--warn)}
.req-detail{margin-left:auto;font-size:.78rem;color:var(--dim);font-family:monospace}

/* Form */
.fg{margin-bottom:.9rem}
label{display:block;font-size:.8rem;font-weight:600;color:var(--muted);margin-bottom:.35rem}
input[type=text],input[type=password],input[type=url],textarea{
  width:100%;background:#1a1e2b;border:1px solid var(--border);border-radius:var(--r);
  color:var(--text);font-size:.9rem;font-family:inherit;padding:.65rem .9rem;outline:none;
  transition:border-color .15s,box-shadow .15s}
input:focus,textarea:focus{border-color:rgba(124,92,252,.6);
  box-shadow:0 0 0 3px rgba(124,92,252,.12)}
textarea{resize:vertical;min-height:110px;font-family:monospace;font-size:.8rem;line-height:1.5}
.hint{font-size:.76rem;color:var(--dim);margin-top:.3rem}
.grid-2{display:grid;grid-template-columns:1fr 90px;gap:.75rem}
.grid-3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:.75rem}

/* Key display */
.key-box{font-family:monospace;font-size:.78rem;word-break:break-all;
  background:#0e1119;border-radius:6px;padding:.5rem .7rem;
  color:var(--accent);border:1px solid var(--border);line-height:1.6;user-select:all}

/* Buttons */
.btn{display:inline-flex;align-items:center;gap:.45rem;padding:.65rem 1.35rem;
  border-radius:var(--r);font-size:.88rem;font-weight:600;cursor:pointer;
  border:none;text-decoration:none;transition:filter .15s,transform .15s;white-space:nowrap}
.btn-primary{background:var(--primary);color:#fff}
.btn-primary:hover{filter:brightness(1.1);transform:translateY(-1px)}
.btn-secondary{background:#1a1e2b;border:1px solid var(--border);color:var(--muted)}
.btn-secondary:hover{color:var(--text)}
.btn-sm{padding:.4rem .85rem;font-size:.8rem}
.btn-danger{background:rgba(255,69,96,.1);color:var(--danger);border:1px solid rgba(255,69,96,.3)}
.btn-danger:hover{background:var(--danger);color:#fff}
.btn[disabled]{opacity:.45;pointer-events:none}

/* Alerts */
.alert{border-radius:var(--r);padding:.85rem 1rem;font-size:.86rem;margin-bottom:1.1rem;line-height:1.5}
.alert-err{background:rgba(255,69,96,.1);border:1px solid rgba(255,69,96,.25);color:var(--danger)}
.alert-ok{background:rgba(0,212,163,.1);border:1px solid rgba(0,212,163,.25);color:var(--accent)}
.alert-warn{background:rgba(255,178,63,.1);border:1px solid rgba(255,178,63,.25);color:var(--warn)}

/* Nav row */
.nav-row{display:flex;justify-content:space-between;align-items:center;margin-top:1.5rem;gap:.75rem}

/* Section header */
.sh{font-size:.7rem;font-weight:700;letter-spacing:.09em;text-transform:uppercase;
  color:var(--dim);margin:1.35rem 0 .7rem}

/* Summary rows */
.sum-row{display:flex;align-items:center;gap:.7rem;padding:.45rem 0;
  border-bottom:1px solid var(--border);font-size:.87rem}
.sum-row:last-child{border:none}

/* Success */
.big-icon{font-size:3rem;text-align:center;margin:1rem 0}
.next-list{display:flex;flex-direction:column;gap:.5rem;margin:1rem 0}
.next-list li{display:flex;gap:.6rem;font-size:.87rem;list-style:none}
.next-list li::before{content:'→';color:var(--accent);flex-shrink:0}
code{background:#0e1119;border-radius:4px;padding:.15rem .4rem;
  font-family:monospace;font-size:.82em;color:var(--accent)}
hr{border:none;border-top:1px solid var(--border);margin:1.25rem 0}

@media(max-width:480px){.grid-3{grid-template-columns:1fr 1fr}.card{padding:1.25rem}}
</style>
</head>
<body>

<!-- Brand -->
<div class="brand">
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor"
       stroke-width="2.5" stroke-linecap="round">
    <path d="M6 12H18M3 6H7M17 6H21M3 18H7M17 18H21M7 6V18M17 6V18"/>
  </svg>
  WorkTrack Installer
</div>

<div class="card">

  <!-- Progress bar -->
  <div class="prog">
    <?php for ($i = 1; $i <= 6; $i++): ?>
    <div class="ps <?= $i < $step ? 'done' : ($i === $step ? 'active' : '') ?>"></div>
    <?php endfor; ?>
  </div>
  <div class="step-lbl">Step <?= $step ?> of 6 &mdash; <?= $stepNames[$step - 1] ?></div>

  <!-- Errors -->
  <?php if ($errors): ?>
  <div class="alert alert-err">
    <?php foreach ($errors as $e): ?><div><?= h($e) ?></div><?php endforeach; ?>
  </div>
  <?php endif; ?>

<?php /* ═══════════════════════════════════ STEP 1 ══ */ if ($step === 1): ?>

  <h1>System Requirements</h1>
  <p class="sub">All required items must pass before you can continue.</p>

  <?php foreach ($req as [$label, $pass, $detail]): ?>
  <div class="req-row">
    <div class="dot <?= $pass ? 'ok' : 'fail' ?>"><?= $pass ? '✓' : '✗' ?></div>
    <span><?= h($label) ?></span>
    <?php if ($detail !== ''): ?>
    <span class="req-detail"><?= h($detail) ?></span>
    <?php endif; ?>
  </div>
  <?php endforeach; ?>

  <?php if (!$allOk): ?>
  <div class="alert alert-err" style="margin-top:1rem">
    One or more requirements are not met. Install missing PHP extensions and check directory permissions, then reload this page.
  </div>
  <?php endif; ?>

  <div class="nav-row">
    <span></span>
    <a href="install.php?step=2" class="btn btn-primary <?= $allOk ? '' : 'btn-disabled' ?>"
       <?= $allOk ? '' : 'onclick="return false" style="opacity:.4;pointer-events:none"' ?>>
      Continue →
    </a>
  </div>

<?php /* ═══════════════════════════════════ STEP 2 ══ */ elseif ($step === 2):
  $saved = $_SESSION['install']['db'] ?? [];
?>

  <h1>Database Connection</h1>
  <p class="sub">
    WorkTrack needs a MariaDB or MySQL database. The installer will create the database and all tables automatically if the user has <code>CREATE</code> permission.
  </p>

  <form method="POST" action="install.php?step=2">
    <input type="hidden" name="_csrf" value="<?= h($csrf) ?>">

    <div class="grid-2">
      <div class="fg">
        <label>Host</label>
        <input type="text" name="db_host" value="<?= h($saved['host'] ?? 'localhost') ?>" required>
      </div>
      <div class="fg">
        <label>Port</label>
        <input type="text" name="db_port" value="<?= h($saved['port'] ?? '3306') ?>" required>
      </div>
    </div>

    <div class="fg">
      <label>Database name</label>
      <input type="text" name="db_name" value="<?= h($saved['name'] ?? 'worktrack') ?>" required>
      <div class="hint">Created automatically if it does not exist and the user has CREATE privilege.</div>
    </div>
    <div class="fg">
      <label>Username</label>
      <input type="text" name="db_user" value="<?= h($saved['user'] ?? '') ?>" required autocomplete="username">
    </div>
    <div class="fg">
      <label>Password</label>
      <input type="password" name="db_pass" value="<?= h($saved['pass'] ?? '') ?>" required autocomplete="current-password">
    </div>

    <div class="nav-row">
      <a href="install.php?step=1" class="btn btn-secondary">← Back</a>
      <button type="submit" class="btn btn-primary">Test &amp; Continue →</button>
    </div>
  </form>

<?php /* ═══════════════════════════════════ STEP 3 ══ */ elseif ($step === 3):
  $app = $_SESSION['install']['app'] ?? [];
?>

  <h1>Application Configuration</h1>

  <form method="POST" action="install.php?step=3">
    <input type="hidden" name="_csrf" value="<?= h($csrf) ?>">

    <div class="fg">
      <label>Public app URL</label>
      <input type="url" name="app_url" value="<?= h($app['url'] ?? $detectedUrl) ?>" required>
      <div class="hint">No trailing slash. Used as the OAuth callback base URL.</div>
    </div>

    <div class="sh">Security keys — auto-generated, keep these secret</div>
    <div class="alert alert-warn" style="font-size:.82rem;margin-bottom:1rem">
      Back up these three keys. They encrypt all user data. Losing them means losing access to every stored record.
    </div>

    <?php foreach ([
      ['JWT Secret',            'jwt',     'Signs authentication tokens for web and mobile'],
      ['Encryption Key',        'enckey',  'AES-256-GCM — encrypts emails, names, workout notes'],
      ['Search Key',            'srchkey', 'HMAC blind-index — allows lookups without decrypting'],
    ] as [$label, $field, $hint]): ?>
    <div class="fg">
      <label><?= $label ?></label>
      <div class="key-box"><?= h($app[$field] ?? '') ?></div>
      <input type="hidden" name="<?= $field ?>" value="<?= h($app[$field] ?? '') ?>">
      <div class="hint"><?= $hint ?></div>
    </div>
    <?php endforeach; ?>

    <a href="install.php?step=3&regen=1"
       class="btn btn-secondary btn-sm"
       onclick="return confirm('Regenerate all keys? Any existing encrypted data will become unreadable.')">
      ↺ Regenerate keys
    </a>

    <div class="nav-row">
      <a href="install.php?step=2" class="btn btn-secondary">← Back</a>
      <button type="submit" class="btn btn-primary">Continue →</button>
    </div>
  </form>

<?php /* ═══════════════════════════════════ STEP 4 ══ */ elseif ($step === 4):
  $o  = $_SESSION['install']['oauth'] ?? [];
  $cb = h(($app['url'] ?? $detectedUrl) . '/webapp/auth/callback.php');
?>

  <h1>OAuth Sign-In <small style="font-size:.8rem;color:var(--muted);font-weight:400">(optional)</small></h1>
  <p class="sub">
    Email/password always works without configuring these. Register your redirect URI with each provider:<br>
    <code><?= $cb ?></code>
  </p>

  <form method="POST" action="install.php?step=4">
    <input type="hidden" name="_csrf" value="<?= h($csrf) ?>">

    <div class="sh">🔵 Google — <a href="https://console.cloud.google.com" target="_blank" style="color:var(--primary)">console.cloud.google.com</a></div>
    <div class="fg">
      <label>Client ID</label>
      <input type="text" name="google_id" value="<?= h($o['google_id'] ?? '') ?>" placeholder="1234….apps.googleusercontent.com">
    </div>
    <div class="fg">
      <label>Client Secret</label>
      <input type="password" name="google_secret" value="<?= h($o['google_secret'] ?? '') ?>">
    </div>

    <hr>
    <div class="sh">📘 Facebook — <a href="https://developers.facebook.com" target="_blank" style="color:var(--primary)">developers.facebook.com</a></div>
    <div class="fg">
      <label>App ID</label>
      <input type="text" name="fb_id" value="<?= h($o['fb_id'] ?? '') ?>">
    </div>
    <div class="fg">
      <label>App Secret</label>
      <input type="password" name="fb_secret" value="<?= h($o['fb_secret'] ?? '') ?>">
    </div>

    <hr>
    <div class="sh">🍎 Apple — <a href="https://developer.apple.com" target="_blank" style="color:var(--primary)">developer.apple.com</a> (Services ID + .p8 key)</div>
    <div class="grid-3">
      <div class="fg">
        <label>Services ID</label>
        <input type="text" name="apple_id" value="<?= h($o['apple_id'] ?? '') ?>" placeholder="com.example.app">
      </div>
      <div class="fg">
        <label>Team ID</label>
        <input type="text" name="apple_team" value="<?= h($o['apple_team'] ?? '') ?>">
      </div>
      <div class="fg">
        <label>Key ID</label>
        <input type="text" name="apple_key_id" value="<?= h($o['apple_key_id'] ?? '') ?>">
      </div>
    </div>
    <div class="fg">
      <label>Private key (.p8 file contents)</label>
      <textarea name="apple_pem" placeholder="-----BEGIN PRIVATE KEY-----&#10;…&#10;-----END PRIVATE KEY-----"><?= h($o['apple_pem'] ?? '') ?></textarea>
    </div>

    <div class="nav-row">
      <a href="install.php?step=3" class="btn btn-secondary">← Back</a>
      <button type="submit" class="btn btn-primary">Continue →</button>
    </div>
  </form>

<?php /* ═══════════════════════════════════ STEP 5 ══ */ elseif ($step === 5):
  $d  = $_SESSION['install']['db']    ?? [];
  $a  = $_SESSION['install']['app']   ?? [];
  $o  = $_SESSION['install']['oauth'] ?? [];
  $providers = array_filter([
    !empty($o['google_id']) ? 'Google'   : '',
    !empty($o['fb_id'])     ? 'Facebook' : '',
    !empty($o['apple_id'])  ? 'Apple'    : '',
  ]);
?>

  <h1>Review &amp; Install</h1>
  <p class="sub">Everything looks good. Click <strong>Install</strong> to create the database tables, load 174 exercises, and write <code>config.php</code>.</p>

  <div class="sum-row"><div class="dot ok">✓</div>
    <span>Database: <strong><?= h($d['user'] ?? '') ?>@<?= h($d['host'] ?? '') ?>/<?= h($d['name'] ?? '') ?></strong></span>
  </div>
  <div class="sum-row"><div class="dot ok">✓</div>
    <span>App URL: <strong><?= h($a['url'] ?? '') ?></strong></span>
  </div>
  <div class="sum-row"><div class="dot ok">✓</div>
    <span>Three AES-256-GCM + HMAC security keys generated</span>
  </div>
  <div class="sum-row">
    <div class="dot <?= $providers ? 'ok' : 'skip' ?>"><?= $providers ? '✓' : '–' ?></div>
    <span>OAuth: <?= $providers ? h(implode(', ', $providers)) : 'not configured (add to config.php later)' ?></span>
  </div>

  <form method="POST" action="install.php?step=5" style="margin-top:1.5rem">
    <input type="hidden" name="_csrf" value="<?= h($csrf) ?>">
    <div class="nav-row">
      <a href="install.php?step=4" class="btn btn-secondary">← Back</a>
      <button type="submit" class="btn btn-primary">▶ Install WorkTrack</button>
    </div>
  </form>

<?php /* ═══════════════════════════════════ STEP 6 ══ */ elseif ($step === 6):
  $appUrl = h($_SESSION['install']['app']['url'] ?? '');
?>

  <div class="big-icon">🎉</div>
  <h1 style="text-align:center;color:var(--accent)">Installation complete!</h1>

  <ul class="next-list">
    <li>Database tables created — 174 exercises seeded</li>
    <li>All three security keys written to <code>config.php</code></li>
    <li>Web app live at <a href="<?= $appUrl ?>/webapp/" target="_blank" style="color:var(--primary)"><?= $appUrl ?>/webapp/</a></li>
    <li>Sign-in page: <code><?= $appUrl ?>/webapp/auth/login.php</code></li>
    <li>Mobile/watch API base URL: <code><?= $appUrl ?>/</code></li>
  </ul>

  <hr>

  <div class="alert alert-warn" style="font-size:.84rem">
    <strong>Action required:</strong> delete or restrict access to <code>install.php</code> now — it bypasses authentication and could allow reconfiguration by anyone who finds it.
  </div>

  <div style="display:flex;gap:.75rem;flex-wrap:wrap;margin-top:1rem">
    <a href="<?= $appUrl ?>/webapp/" class="btn btn-primary">Open WorkTrack →</a>
    <a href="install.php?step=6&delete=1" class="btn btn-danger"
       onclick="return confirm('Delete install.php now? This is recommended.')">
      🗑 Delete install.php
    </a>
  </div>

<?php endif; ?>

</div><!-- .card -->
</body>
</html>
