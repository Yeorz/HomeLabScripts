<?php
/**
 * Application-level field encryption — AES-256-GCM (authenticated).
 *
 * Even a full database dump is useless without the two keys in config.php:
 *   APP_ENCRYPTION_KEY — 64-char hex (32 bytes) for AES-256-GCM
 *   APP_SEARCH_KEY     — 64-char hex (32 bytes) for HMAC blind indexes
 *
 * Wire format stored in the DB (base64 encoded):
 *   [ 12-byte nonce | 16-byte GCM auth-tag | ciphertext ]
 *
 * Fields that are encrypted:
 *   users           : email, name, oauth_id
 *   workouts        : name, notes
 *   workout_exercises: custom_name, notes
 *   sets            : notes
 *
 * Fields that stay plain (required for SQL aggregations / relations):
 *   All IDs, dates, numeric metrics (weight, reps, calories…), enums,
 *   bcrypt password hashes, exercise library content.
 *
 * Blind indexes (HMAC — enables WHERE lookups without decrypting):
 *   users.email_hash    = searchHash(email)
 *   users.oauth_search  = searchHash(provider . ':' . oauth_id)
 */

// ── Key loading ───────────────────────────────────────────────────────────

function _cryptoEncKey(): string {
    static $k = null;
    if ($k === null) {
        if (!defined('APP_ENCRYPTION_KEY') || strlen(APP_ENCRYPTION_KEY) !== 64) {
            throw new RuntimeException(
                'APP_ENCRYPTION_KEY must be a 64-character hex string. ' .
                'Generate with: php -r "echo bin2hex(random_bytes(32));"'
            );
        }
        $k = hex2bin(APP_ENCRYPTION_KEY);
    }
    return $k;
}

function _cryptoSearchKey(): string {
    static $k = null;
    if ($k === null) {
        if (!defined('APP_SEARCH_KEY') || strlen(APP_SEARCH_KEY) !== 64) {
            throw new RuntimeException(
                'APP_SEARCH_KEY must be a 64-character hex string. ' .
                'Generate with: php -r "echo bin2hex(random_bytes(32));"'
            );
        }
        $k = hex2bin(APP_SEARCH_KEY);
    }
    return $k;
}

// ── Encrypt / decrypt ─────────────────────────────────────────────────────

/**
 * Encrypt a string value for database storage.
 * Returns null/empty unchanged so nullable columns stay nullable.
 */
function encryptField(?string $value): ?string {
    if ($value === null || $value === '') return $value;
    $nonce = random_bytes(12);          // 96-bit nonce — unique per call
    $tag   = '';
    $ct    = openssl_encrypt(
        $value, 'aes-256-gcm', _cryptoEncKey(),
        OPENSSL_RAW_DATA, $nonce, $tag, '', 16
    );
    if ($ct === false) throw new RuntimeException('Encryption failed');
    return base64_encode($nonce . $tag . $ct);
}

/**
 * Decrypt a value retrieved from the database.
 * Returns null if the value is corrupt or the key is wrong (GCM tag mismatch).
 */
function decryptField(?string $value): ?string {
    if ($value === null || $value === '') return $value;
    $raw = base64_decode($value, true);
    // Minimum valid length: 12 (nonce) + 16 (tag) + 1 (ciphertext byte)
    if ($raw === false || strlen($raw) < 29) return null;
    $pt = openssl_decrypt(
        substr($raw, 28),   // ciphertext
        'aes-256-gcm', _cryptoEncKey(), OPENSSL_RAW_DATA,
        substr($raw, 0, 12),    // nonce
        substr($raw, 12, 16)    // auth tag — GCM will reject tampered data
    );
    return $pt === false ? null : $pt;
}

/**
 * Decrypt with a fallback value if the field is null, empty, or corrupt.
 * Use this everywhere you render encrypted data so the UI never crashes.
 */
function df(?string $value, string $fallback = ''): string {
    if ($value === null || $value === '') return $fallback;
    return decryptField($value) ?? $fallback;
}

// ── Blind indexes ─────────────────────────────────────────────────────────

/**
 * Deterministic HMAC-SHA256 of a value used for WHERE-clause lookups.
 * A separate key ensures this hash cannot be used to derive the ciphertext.
 *
 * @param bool $normalize  Lowercase + trim before hashing (true for email).
 */
function searchHash(?string $value, bool $normalize = true): ?string {
    if ($value === null || $value === '') return null;
    $v = $normalize ? mb_strtolower(trim($value)) : trim($value);
    return hash_hmac('sha256', $v, _cryptoSearchKey());
}

// ── Batch helpers ─────────────────────────────────────────────────────────

/**
 * Decrypt a list of named fields inside a DB result row.
 * Any field not present in the row is silently ignored.
 */
function decryptRow(array $row, array $fields): array {
    foreach ($fields as $f) {
        if (array_key_exists($f, $row)) {
            $row[$f] = decryptField($row[$f]);
        }
    }
    return $row;
}

/**
 * Decrypt the same fields in every row of a result set.
 */
function decryptRows(array $rows, array $fields): array {
    return array_map(fn($r) => decryptRow($r, $fields), $rows);
}

// ── Detection helper (for migration only) ────────────────────────────────

/**
 * Returns true if the value looks like our wire format.
 * Used by migrate_encrypt.php to skip already-encrypted rows.
 */
function looksEncrypted(?string $value): bool {
    if ($value === null || strlen($value) < 40) return false;
    $raw = base64_decode($value, true);
    return $raw !== false && strlen($raw) >= 29;
}
