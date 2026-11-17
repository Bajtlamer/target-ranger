#!/usr/bin/env python3
"""Validate runtime paths, icon metadata and Lua 5.1 compilation."""
import re
import shutil
import struct
import subprocess
from package import ADDON, MANIFEST, RUNTIME, files, version

lua = shutil.which('luajit')
if not lua:
    raise SystemExit('LuaJIT required (Lua 5.1 semantics)')
manifest = (RUNTIME / MANIFEST).read_text()
assert '## Interface: 16001' in manifest
assert '## IconTexture: Interface\\AddOns\\' + ADDON + '\\Artwork\\AddonIcon' in manifest
assert re.fullmatch(r'\d+\.\d+\.\d+', version())
raw = (RUNTIME / 'Artwork/AddonIcon.tga').read_bytes()
assert raw[2] == 2 and struct.unpack_from('<HHB', raw, 12) == (64, 64, 32)
assert len(raw) == 18 + 64 * 64 * 4
paths = files()
for path in paths:
    if path.suffix == '.lua':
        subprocess.run([lua, '-e', 'assert(loadfile(arg[1])); os.exit(0)', str(path)], check=True)
print('PASS runtime paths, stable version, icon metadata/texture and Lua 5.1 compilation: ' + str(len(paths)) + ' files')
