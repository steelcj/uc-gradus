# Ansible in a versioned virtual environment

Ansible runs on the controller, your laptop, and nothing Ansible-related is installed on the server beyond Python. On the laptop it lives in its own Python virtual environment, one per Ansible release, at `~/.venvs/ansible/<version>/ansible`. A versioned path means a new release is installed next to the old one, tested, and switched to with one symlink, and the old one stays available to roll back to. Nothing goes into the system Python, and Mint's own `ansible` package is not needed.

The version is the version of the `ansible` package on PyPI, which bundles a matching `ansible-core` plus the community collections. For this repo it is pinned in `ansible/controller-requirements.txt`:

```
ansible==14.5.0
```

Ansible 14.5.0 installs ansible-core 2.21 and the `ansible.posix` and `community.general` collections the playbooks use. It needs Python 3.12 or later, which is what Mint 22.3 ships.

## Layout

```
~/.venvs/ansible/
    14.5.0/
        ansible/            the virtual environment
        pip-freeze.txt      exactly what was installed
    current -> 14.5.0/ansible
```

`current` is the release you use day to day. Older release directories stay until you delete them.

## Prerequisites

```sh
python3 --version                          # 3.12 or later
sudo apt install python3-venv python3-pip
```

`python3-venv` is the one that matters. Each environment gets its own pip from it, so `python3-pip` only adds a system-wide `pip` command, which is handy for the version check below before any environment exists.

If Mint's packaged Ansible is installed, it is harmless but confusing, because `ansible` then means different things in different shells. Check with `which -a ansible`, and remove it with `sudo apt remove ansible ansible-core` if you want only one.

## Available Ansible versions

```sh
python3 -m pip index versions ansible
```

The first line is the newest release, followed by every release that installs on this Python; add `--pre` to include pre-releases. Inside an active environment use `python -m pip`, which also shows the installed version. The `ansible` version is not the ansible-core version. To see which ansible-core a release brings, without installing it, run this with an environment active (outside one, Mint refuses any `pip install`, even a dry run, to protect the system Python):

```sh
python -m pip install --dry-run --ignore-installed --quiet --report - "ansible==14.5.0" \
  | python -c 'import json,sys; print([i["metadata"]["name"]+" "+i["metadata"]["version"] for i in json.load(sys.stdin)["install"] if i["metadata"]["name"].startswith("ansible")])'
```

## Create it

### With the script

From the repo root:

```sh
./tools/make-ansible-venv.sh
```

If it says permission denied, the executable bit was lost on the way (some archive tools drop it); `chmod +x tools/*.sh test/incus/*.sh bootstrap/*.sh` restores it for all the scripts.

It reads the version from `ansible/controller-requirements.txt`, checks the Python version and venv support, creates `~/.venvs/ansible/14.5.0/ansible`, upgrades pip inside it, installs `ansible==14.5.0`, writes `pip-freeze.txt`, and points `current` at the new environment. Running it again for a version that already exists only moves `current`. To build a different release without editing the file, pass it as an argument: `./tools/make-ansible-venv.sh 14.4.0`.

### By hand

The same steps, if you would rather see each one:

```sh
ANSIBLE_VERSION=14.5.0
VENV="$HOME/.venvs/ansible/$ANSIBLE_VERSION/ansible"
mkdir -p "$(dirname "$VENV")"
python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install "ansible==$ANSIBLE_VERSION"
"$VENV/bin/python" -m pip freeze > "$(dirname "$VENV")/pip-freeze.txt"
ln -sfn "$ANSIBLE_VERSION/ansible" "$HOME/.venvs/ansible/current"
```

## Use it

Activate it in the shell where you run the playbooks. The prompt then starts with `(ansible)`:

```sh
. ~/.venvs/ansible/current/bin/activate
ansible --version
```

The output should show `executable location` and `python version` inside `~/.venvs/ansible/14.5.0/ansible`. If it shows `/usr/bin`, the environment is not active. `deactivate` leaves it.

For a shorter command, add an alias to `~/.bashrc`:

```sh
alias ansible-env='. ~/.venvs/ansible/current/bin/activate'
```

Activating per shell is deliberate. Putting the environment's `bin` directory on your `PATH` permanently would also put its `python3` and `pip` first, shadowing the system Python for everything else you run.

## Roles and collections

The collections come inside the `ansible` package, so nothing extra is needed for them. With the environment active, from `ansible/`:

```sh
ansible-galaxy install -r RESOLVE-requirements.yml
ansible-galaxy collection list | grep -E 'ansible.posix|community.general'
```

The first command fetches the two Robert de Bock roles from GitHub into `ansible/roles/` (set by `roles_path` in `ansible.cfg`, and ignored by git). For the collections it reports "Nothing to do. All requested collections are already installed", because the bundled ones satisfy `RESOLVE-requirements.yml`, so it does not contact Galaxy for them. The second command shows them living in the environment's `site-packages`.

The roles are tied to the repo rather than to the environment, so switching Ansible releases does not touch them.

## Upgrade

Check what is available, with the environment active:

```sh
python -m pip index versions ansible
```

Then:

1. Change the pin in `ansible/controller-requirements.txt`, for example to `ansible==14.6.0`.
2. Run `./tools/make-ansible-venv.sh`. It builds `~/.venvs/ansible/14.6.0/ansible` next to the existing one and moves `current` to it.
3. Open a new shell (or `deactivate` and activate again) and confirm `ansible --version`.
4. Run the rehearsal in `docs/incus-testing.md` against a fresh test instance, including the second `RESOLVE-base.yml` run that should report `changed=0`.
5. Compare `~/.venvs/ansible/14.5.0/pip-freeze.txt` with the new one if anything behaves differently; the bundled collection versions are listed there.

To roll back, point `current` at the previous release:

```sh
ln -sfn 14.5.0/ansible ~/.venvs/ansible/current
```

Once the new release has run against the real server without trouble, delete the old one with `rm -r ~/.venvs/ansible/14.5.0`.

A major Ansible release (14 to 15, say) can drop support for older Python versions on the controller or the target, and can change collection behaviour. Read its porting guide before moving the pin.

## Extra tools

Tools that belong with this Ansible release can go into the same environment, for example the linter:

```sh
python -m pip install ansible-lint
python -m pip freeze > ~/.venvs/ansible/14.5.0/pip-freeze.txt
```

Tools that are independent of Ansible, like `ssh-audit`, are better installed with `pipx`, which gives each one its own environment.

## Remove it

Everything lives under one directory:

```sh
rm -r ~/.venvs/ansible
```
