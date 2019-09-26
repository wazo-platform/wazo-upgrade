# wazo-upgrade

## Branches

* branch `master`: builds package for Wazo current (distribution wazo-dev-buster/pelican-buster)

## Upgrade scripts

* `pre-stop` and `post-stop` scripts must be compatible with the previous Debian version: they will be run at the beginning of `wazo-dist-upgrade`.
* Naming conventions:
  * prefix scripts with two digits
  * use only "-" in the scripts name, not "_"
  * always keep file extension