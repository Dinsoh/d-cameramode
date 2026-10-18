#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONPATH="${PHOTOMODE_TEST_DEPS:-/workspace/.photomode-tools}${PYTHONPATH:+:$PYTHONPATH}"
python3 -m unittest discover -s tests -p 'test_client.py'
python3 -m unittest discover -s tests -p 'test_sessions.py'
python3 -m unittest discover -s tests -p 'test_polaroid.py'
if [[ -n "${QS_REFERENCE_DIR:-}" ]]; then
  python3 -m unittest discover -s tests -p 'test_qs_reference.py'
fi
node --test tests/test_storage.cjs tests/test_fivemanage.cjs tests/test_storage_bridge.cjs
python3 tests/test_ui.py
python3 tests/test_photo_viewer.py
for script in d-photomode/html/app.js d-photomode/html/photo.js d-photomode/storage.js d-photomode/storage-core.js d-photomode/fivemanage.js; do
  node --check "$script"
done
python3 - <<'PY'
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime()
for path in Path('d-photomode').glob('*.lua'):
    lua.execute('assert(load(...))', path.read_text())
# Install snippets are intentionally fragments inside their destination tables.
for name in ['items.lua', 'metadata.lua']:
    lua.execute('assert(load(...))', 'return {'+(Path('d-photomode/install')/name).read_text()+'}')
print('Lua 5.4 resource and install-fragment syntax passed')
PY
git diff --check
