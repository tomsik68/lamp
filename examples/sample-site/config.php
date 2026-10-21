<?php
// Works unchanged in both images: tomsik68/xampp (root, empty password)
// and tomsik68/lamp (root/root). Override with DB_HOST/DB_USER/DB_PASSWORD.
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function db_connect(): mysqli
{
    $host = getenv('DB_HOST') ?: '127.0.0.1';
    $user = getenv('DB_USER') ?: 'root';
    $passwords = getenv('DB_PASSWORD') !== false ? [getenv('DB_PASSWORD')] : ['root', ''];
    $last = null;
    foreach ($passwords as $password) {
        try {
            $db = new mysqli($host, $user, $password);
            $db->set_charset('utf8mb4');
            return $db;
        } catch (mysqli_sql_exception $e) {
            $last = $e;
        }
    }
    throw $last;
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}
