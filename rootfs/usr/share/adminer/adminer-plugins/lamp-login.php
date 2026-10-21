<?php
// Pre-fill the login form with this image's defaults: server localhost
// (the empty field), user root. Adminer loads adminer-plugins/*.php on its own.
class AdminerLampLogin extends Adminer\Plugin {
	function loginFormField($name, $heading, $value) {
		if ($name == 'username' && ($_GET['username'] ?? '') == '') {
			return $heading . str_replace('value=""', 'value="root"', $value) . "\n";
		}
	}
}
