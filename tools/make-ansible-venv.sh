#!/bin/sh
# Builds an Ansible virtual environment at ~/.venvs/ansible/<version>/ansible,
# with the version taken from ansible/controller-requirements.txt (or given as
# an argument), and points ~/.venvs/ansible/current at it.
#
# Usage: tools/make-ansible-venv.sh [ansible-version]
# Environment: VENVS_ROOT (default ~/.venvs/ansible), PYTHON (default python3)
set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
REQS="$HERE/ansible/controller-requirements.txt"
ROOT="${VENVS_ROOT:-$HOME/.venvs/ansible}"
PYTHON="${PYTHON:-python3}"

version="${1:-$(sed -n 's/^ansible==\([^ ]*\).*/\1/p' "$REQS" | head -1)}"
[ -n "$version" ] || { echo "No ansible==<version> line in $REQS" >&2; exit 1; }

venv="$ROOT/$version/ansible"

"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' \
  || { echo "$PYTHON is older than 3.12, which ansible-core 2.20 and later need." >&2; exit 1; }
"$PYTHON" -c 'import venv, ensurepip' 2>/dev/null \
  || { echo "Python venv support missing. On Mint or Debian: sudo apt install python3-venv" >&2; exit 1; }

if [ -x "$venv/bin/ansible" ]; then
  echo "Already present: $venv"
else
  echo "Creating $venv"
  mkdir -p "$ROOT/$version"
  "$PYTHON" -m venv "$venv"
  "$venv/bin/python" -m pip install --quiet --upgrade pip
  "$venv/bin/python" -m pip install --quiet "ansible==$version"
  # Record exactly what was installed, for comparison when upgrading.
  "$venv/bin/python" -m pip freeze > "$ROOT/$version/pip-freeze.txt"
fi

ln -sfn "$version/ansible" "$ROOT/current"

"$venv/bin/ansible" --version | head -1
echo "Activate with: . $ROOT/current/bin/activate"
