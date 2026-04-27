<?php
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';

clearAuthCookie();
header('Location: /webapp/auth/login.php');
exit;
