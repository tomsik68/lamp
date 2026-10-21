<?php require __DIR__ . '/config.php'; ?>
<!doctype html>
<meta charset="utf-8">
<title>LAMP sample site</title>
<h1>LAMP sample site</h1>
<p>PHP <?= h(PHP_VERSION) ?> on <?= h($_SERVER['SERVER_SOFTWARE'] ?? 'unknown') ?></p>
<ul>
  <li><a href="info.php">phpinfo()</a></li>
  <li><a href="guestbook.php">Guestbook (MariaDB)</a></li>
</ul>
