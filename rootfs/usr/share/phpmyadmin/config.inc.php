<?php
// Log in with real MariaDB credentials; passwordless root is never allowed.
$cfg['blowfish_secret'] = getenv('PMA_BLOWFISH_SECRET') ?: hash('sha256', php_uname() . __FILE__);
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['host'] = 'localhost';
$cfg['Servers'][1]['AllowNoPassword'] = false;
$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';
