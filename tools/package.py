#!/usr/bin/env python3
"""Package only manifest-loaded runtime files and the addon emblem."""
import hashlib
import pathlib
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'TargetRanger'
ADDON = 'TargetRanger'
MANIFEST = 'TargetRanger.toc'


def version():
    return re.search(r'^## Version: (\d+\.\d+\.\d+)$', (RUNTIME / MANIFEST).read_text(), re.M).group(1)


def files():
    result = [RUNTIME / MANIFEST, RUNTIME / 'Artwork/AddonIcon.tga']
    def include(path):
        if not path.is_file() or not path.resolve().is_relative_to(RUNTIME.resolve()):
            raise ValueError('Invalid runtime file: ' + str(path))
        if path in result:
            return
        result.append(path)
        if path.suffix.lower() == '.xml':
            for element in ET.parse(path).iter():
                if element.tag.rsplit('}', 1)[-1] in ('Script', 'Include') and element.get('file'):
                    include(path.parent / element.get('file').replace('\\', '/'))
    for line in (RUNTIME / MANIFEST).read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            include(RUNTIME / line.strip().replace('\\', '/'))
    for path in result:
        if not path.is_file():
            raise ValueError('Missing runtime file: ' + str(path))
    return result


if __name__ == '__main__':
    target = ROOT / 'dist' / (ADDON + '-' + version() + '.zip')
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in files():
            info = zipfile.ZipInfo(ADDON + '/' + path.relative_to(RUNTIME).as_posix(), (2026, 11, 16, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, path.read_bytes())
    (target.parent / 'SHA256SUMS').write_text(hashlib.sha256(target.read_bytes()).hexdigest() + '  ' + target.name + '\n')
    print(target)
