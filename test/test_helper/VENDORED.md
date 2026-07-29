# Vendored bats helper libraries

Submodules can't be used in this repo's checkout (`.gitmodules` is not
writable in some environments), so bats-support and bats-assert are
vendored as plain copied files (LICENSE, `load.bash`, `src/`) instead of
their `test/`, `docs/`, and `package*.json`.

| Library      | Upstream                                       | Commit                                  |
|--------------|-------------------------------------------------|------------------------------------------|
| bats-support | https://github.com/bats-core/bats-support | 0954abb9925cad550424cebca2b99255d4eabe96 |
| bats-assert  | https://github.com/bats-core/bats-assert  | 697471b7a89d3ab38571f38c6c7c4b460d1f5e35 |

To update, re-clone the upstream repo at a newer commit and re-copy the
same files.
