<?php
require __DIR__ . '/config.php';

$db = db_connect();
$db->query('CREATE DATABASE IF NOT EXISTS sample');
$db->select_db('sample');
$db->query('CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && trim($_POST['name'] ?? '') !== '' && trim($_POST['message'] ?? '') !== '') {
    $stmt = $db->prepare('INSERT INTO messages (name, message) VALUES (?, ?)');
    $stmt->bind_param('ss', $_POST['name'], $_POST['message']);
    $stmt->execute();
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

$server = $db->query('SELECT VERSION()')->fetch_row()[0];
$messages = $db->query('SELECT name, message, created_at FROM messages ORDER BY id DESC')->fetch_all(MYSQLI_ASSOC);
?>
<!doctype html>
<meta charset="utf-8">
<title>Guestbook</title>
<h1>Guestbook</h1>
<p>Connected to <?= h($server) ?>. <a href="index.php">Back</a></p>
<form method="post">
  <input name="name" placeholder="Name" required>
  <input name="message" placeholder="Message" required size="40">
  <button>Sign</button>
</form>
<h2><?= count($messages) ?> message(s)</h2>
<ul>
<?php foreach ($messages as $m): ?>
  <li><b><?= h($m['name']) ?></b> (<?= h($m['created_at']) ?>): <?= h($m['message']) ?></li>
<?php endforeach; ?>
</ul>
