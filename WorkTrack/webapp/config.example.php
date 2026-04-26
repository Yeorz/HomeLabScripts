<?php
// Copy this file to config.php and fill in your values
define('DB_HOST',    'localhost');
define('DB_PORT',    '3306');
define('DB_NAME',    'worktrack');
define('DB_USER',    'worktrack_user');
define('DB_PASS',    'change_this_password');
define('DB_CHARSET', 'utf8mb4');

// JWT secret — used for mobile/watch API auth tokens.
// Generate a random value: php -r "echo bin2hex(random_bytes(32));"
define('JWT_SECRET', 'change_this_to_a_long_random_string');
