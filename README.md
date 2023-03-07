# wazo-upgrade

## Branches

* branch `master`: builds package for Wazo current (distribution wazo-dev-bullseye/pelican-bullseye)

## Upgrade scripts

* `pre-stop` and `post-stop` scripts must be compatible with the previous Debian version: they will
  be run at the beginning of `wazo-dist-upgrade`.
* Naming conventions:
  * prefix scripts with two digits
  * use only `-` in the scripts name, not `_`
  * always keep file extension
* Shell scripts should have the following options (pure shell script doesn't accept `-o` option):

  ```
  set -e
  set -u  # fail if variable is undefined
  set -o pipefail  # fail if command before pipe fails
  ```
* each script should check for sentinel file before running and create one at the end.
* sentinel files should not start with digits
* sentinel files should also be created by `debian/wazo-upgrade.postinst`
