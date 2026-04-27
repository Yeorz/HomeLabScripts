<?php
/**
 * One-shot encryption migration.
 *
 * Run ONCE after deploying the encryption update on an existing database:
 *   php webapp/migrate_encrypt.php
 *
 * Safe to re-run — already-encrypted rows are automatically skipped.
 * DELETE this file (or restrict web access to it) after running.
 */

// ── Bootstrap ─────────────────────────────────────────────────────────────
$isCLI = PHP_SAPI === 'cli';
if (!$isCLI) {
    // Allow browser access only with a one-time token set via env var
    $token = getenv('MIGRATE_TOKEN') ?: '';
    $given = $_GET['token'] ?? '';
    if ($token === '' || !hash_equals($token, $given)) {
        http_response_code(403);
        exit('Set MIGRATE_TOKEN env var and pass ?token=<value> to run via browser.');
    }
}

define('WORKTRACK_MIGRATION', true);

$root = dirname(__FILE__);
require_once $root . '/includes/db.php';
require_once $root . '/includes/crypto.php';

$pdo = getDB();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$counts = ['users' => 0, 'workouts' => 0, 'workout_exercises' => 0, 'sets' => 0];
$errors = [];

function log(string $msg): void {
    echo (PHP_SAPI === 'cli' ? $msg : nl2br(htmlspecialchars($msg))) . "\n";
    flush();
}

log("WorkTrack encryption migration — " . date('Y-m-d H:i:s'));
log(str_repeat('-', 60));

// ── users ─────────────────────────────────────────────────────────────────
log("\n[users] Reading rows…");
$rows = $pdo->query('SELECT id, email, name, oauth_id FROM users')->fetchAll();

$upd = $pdo->prepare('UPDATE users SET email = ?, email_hash = ?, name = ?, oauth_id = ?, oauth_search = ? WHERE id = ?');

foreach ($rows as $r) {
    $changed = false;
    $email   = $r['email'];
    $name    = $r['name'];
    $oauthId = $r['oauth_id'];

    // Determine the oauth_provider for the blind index (we need it from the same row)
    // Re-fetch provider here since it's not in the select above
    $provRow  = $pdo->prepare('SELECT oauth_provider FROM users WHERE id = ?');
    $provRow->execute([$r['id']]);
    $provider = $provRow->fetchColumn() ?: '';

    // Encrypt email if it's not already encrypted
    $encEmail   = null;
    $emailHash  = null;
    if ($email !== null && $email !== '') {
        if (!looksEncrypted($email)) {
            $encEmail  = encryptField(mb_strtolower(trim($email)));
            $emailHash = searchHash($email);
            $changed   = true;
        } else {
            $encEmail  = $email; // already encrypted, keep as-is
            // email_hash may be missing even if email is encrypted (partial migration)
            $hashRow = $pdo->prepare('SELECT email_hash FROM users WHERE id = ?');
            $hashRow->execute([$r['id']]);
            $emailHash = $hashRow->fetchColumn() ?: null;
        }
    }

    // Encrypt name
    $encName = null;
    if ($name !== null && $name !== '') {
        if (!looksEncrypted($name)) { $encName = encryptField($name); $changed = true; }
        else                        { $encName = $name; }
    }

    // Encrypt oauth_id and compute oauth_search
    $encOauthId   = null;
    $oauthSearch  = null;
    if ($oauthId !== null && $oauthId !== '' && $provider !== '') {
        if (!looksEncrypted($oauthId)) {
            $encOauthId  = encryptField($oauthId);
            $oauthSearch = searchHash("$provider:$oauthId", false);
            $changed     = true;
        } else {
            $encOauthId = $oauthId;
            // Recompute oauth_search from existing encrypted id — not possible without decrypt
            // Check if it's already set
            $srchRow = $pdo->prepare('SELECT oauth_search FROM users WHERE id = ?');
            $srchRow->execute([$r['id']]);
            $oauthSearch = $srchRow->fetchColumn() ?: null;
        }
    }

    if ($changed) {
        try {
            $upd->execute([$encEmail, $emailHash, $encName, $encOauthId, $oauthSearch, $r['id']]);
            $counts['users']++;
        } catch (PDOException $e) {
            $errors[] = "users #{$r['id']}: " . $e->getMessage();
        }
    }
}
log("  Encrypted {$counts['users']} user row(s).");

// ── workouts ──────────────────────────────────────────────────────────────
log("\n[workouts] Reading rows…");
$rows = $pdo->query('SELECT id, name, notes FROM workouts')->fetchAll();
$upd  = $pdo->prepare('UPDATE workouts SET name = ?, notes = ? WHERE id = ?');

foreach ($rows as $r) {
    $name  = $r['name'];
    $notes = $r['notes'];
    $encN  = null; $encNotes = null; $changed = false;

    if ($name !== null && $name !== '') {
        if (!looksEncrypted($name)) { $encN = encryptField($name); $changed = true; }
        else                        { $encN = $name; }
    }
    if ($notes !== null && $notes !== '') {
        if (!looksEncrypted($notes)) { $encNotes = encryptField($notes); $changed = true; }
        else                         { $encNotes = $notes; }
    }

    if ($changed) {
        try { $upd->execute([$encN, $encNotes, $r['id']]); $counts['workouts']++; }
        catch (PDOException $e) { $errors[] = "workouts #{$r['id']}: " . $e->getMessage(); }
    }
}
log("  Encrypted {$counts['workouts']} workout row(s).");

// ── workout_exercises ─────────────────────────────────────────────────────
log("\n[workout_exercises] Reading rows…");
$rows = $pdo->query('SELECT id, custom_name, notes FROM workout_exercises')->fetchAll();
$upd  = $pdo->prepare('UPDATE workout_exercises SET custom_name = ?, notes = ? WHERE id = ?');

foreach ($rows as $r) {
    $cn = $r['custom_name']; $notes = $r['notes'];
    $encCn = null; $encNotes = null; $changed = false;

    if ($cn !== null && $cn !== '') {
        if (!looksEncrypted($cn)) { $encCn = encryptField($cn); $changed = true; }
        else                      { $encCn = $cn; }
    }
    if ($notes !== null && $notes !== '') {
        if (!looksEncrypted($notes)) { $encNotes = encryptField($notes); $changed = true; }
        else                         { $encNotes = $notes; }
    }

    if ($changed) {
        try { $upd->execute([$encCn, $encNotes, $r['id']]); $counts['workout_exercises']++; }
        catch (PDOException $e) { $errors[] = "workout_exercises #{$r['id']}: " . $e->getMessage(); }
    }
}
log("  Encrypted {$counts['workout_exercises']} exercise row(s).");

// ── sets ──────────────────────────────────────────────────────────────────
log("\n[sets] Reading rows…");
$rows = $pdo->query('SELECT id, notes FROM sets WHERE notes IS NOT NULL AND notes != \'\'')->fetchAll();
$upd  = $pdo->prepare('UPDATE sets SET notes = ? WHERE id = ?');

foreach ($rows as $r) {
    if (!looksEncrypted($r['notes'])) {
        try { $upd->execute([encryptField($r['notes']), $r['id']]); $counts['sets']++; }
        catch (PDOException $e) { $errors[] = "sets #{$r['id']}: " . $e->getMessage(); }
    }
}
log("  Encrypted {$counts['sets']} set row(s).");

// ── Summary ───────────────────────────────────────────────────────────────
log("\n" . str_repeat('-', 60));
log("Done. Rows encrypted: " . array_sum($counts));
foreach ($counts as $t => $n) log("  $t: $n");

if ($errors) {
    log("\nERRORS (" . count($errors) . "):");
    foreach ($errors as $e) log("  $e");
    exit(1);
}

log("\nAll data encrypted successfully.");
log("IMPORTANT: Delete or restrict access to this file now.\n");
