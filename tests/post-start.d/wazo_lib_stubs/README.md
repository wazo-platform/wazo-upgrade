# Stand-ins for the wazo python libraries

`wazo-upgrade` depends on `curl`, `python3`, `jq` and `psmisc` only (see
`debian/control`): the libraries its post-start scripts import belong to a
Wazo stack, not to this package, and the bats job installs neither.

These stand in for them, and for them alone. What a script does over HTTP is
not stubbed: `dird_mock.py` answers it over a socket, so the retry, the status
handling and the JSON parsing under test are the script's own.

`config_helper.read_config_file_hierarchy` reads `FAKE_DIRD_PORT`, which is
how the mock's port reaches the script — the same place a real deployment
takes it from.
