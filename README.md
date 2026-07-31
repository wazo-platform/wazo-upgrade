# wazo-upgrade

## Branches

* branch `master`: builds package for Wazo current (distribution
  wazo-dev-bookworm/pelican-bookworm)

## Upgrade scripts

* `pre-stop` and `post-stop` scripts must be compatible with the previous
  Debian version: they will be run at the beginning of `wazo-dist-upgrade`.

### Failure handling

A script exiting with a non-zero status aborts the upgrade, except in the
`post-start` phase:

* `pre-stop`: the upgrade is aborted (nothing has changed yet).
* `post-stop`: the upgrade is aborted and Wazo services are restarted
  (packages are not upgraded yet).
* `pre-start`: Wazo services are restarted, then the upgrade is aborted and
  reported as partially upgraded. A stopped Wazo is a worse outage than a
  partially upgraded one, which usually keeps taking calls.
* `post-start`: all scripts are executed, then the list of failed scripts
  is printed as a warning. The upgrade is not aborted: the system is
  already upgraded and services are running.

An aborted upgrade makes `wazo-upgrade` exit with a non-zero status. Services
that fail to start abort it too.

A marker file (`/var/lib/wazo-upgrade/upgrade-incomplete`) exists from the
beginning of an upgrade until the services are successfully started. While it
exists, `wazo-upgrade` warns about the incomplete upgrade at startup and skips
the wizard check. Services are restarted before aborting, but a failed start
or an interrupted upgrade leaves Wazo stopped, and that check exits when
`wazo-confd` is not running, which would block the retry.

Consequences for script authors:

* Scripts must be re-entrant: the recovery path after a failure is to fix
  the issue and re-execute `wazo-upgrade`, which runs all scripts of all
  phases again. Use a sentinel file (see below) or make the script
  naturally idempotent.
* Best-effort scripts (cleanups, optional steps) must handle their own
  errors internally (e.g. `|| echo "WARNING: ..."`) with a comment
  explaining why the failure is tolerated — the runner treats any non-zero
  exit as fatal, apart from `post-start`.
* `post-start` scripts run against a live system: failures that are routine
  (an unreachable phone, an offline plugin repository) must be logged and
  contained per item rather than propagated.
* Naming conventions:
  * prefix scripts with two digits
  * use only `-` in the scripts name, not `_`
  * always keep file extension
* Shell scripts should have the following options (pure shell script
  (`#!/bin/sh`) doesn't accept `-o` option):

  ```shell
  set -e
  set -u  # fail if variable is undefined
  set -o pipefail  # fail if command before pipe fails
  ```

* each script should check for sentinel file before running and create one
  at the end.
* sentinel files should not start with digits
* sentinel files should also be created by `debian/wazo-upgrade.postinst`
