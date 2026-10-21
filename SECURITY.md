# Security policy

## Supported versions

Only the current PHP `8.x` tags (see the tag table in the [README](README.md)) receive security fixes. Older or `-beta` tags are not supported.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's [private vulnerability reporting](https://github.com/tomsik68/lamp/security/advisories/new). Do not open a public issue.

## How fixes ship

Fixes ship as image rebuilds. Images are rebuilt automatically when the upstream `php` base image, Debian packages, s6-overlay or Adminer change, so pulling the tag again picks the fix up.
