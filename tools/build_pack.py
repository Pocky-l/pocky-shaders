"""Builds the shader pack zip: build/Pocky Shaders <version>.zip with shaders/ and LICENSE at its root.

Usage: python tools/build_pack.py [--notes]
  --notes  also writes build/release-notes.md from the CHANGELOG.md section of pack_version (fails if it is missing)

Prints the path of the zip. Entries get a fixed timestamp, so the same sources give the same zip.
"""
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXED_TIME = (2026, 1, 1, 0, 0, 0)


def properties():
    props = {}
    for line in (ROOT / 'pack.properties').read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            props[key.strip()] = value.strip()
    return props


def changelog_section(version):
    text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    match = re.search(r'^## \[' + re.escape(version) + r'\][^\n]*\n(.*?)(?=^## \[|\Z)', text, re.M | re.S)
    if not match or not match.group(1).strip():
        raise SystemExit(f'CHANGELOG.md has no section for {version}')
    return match.group(1).strip() + '\n'


def build(props):
    out = ROOT / 'build' / f"{props['pack_name']} {props['pack_version']}.zip"
    out.parent.mkdir(exist_ok=True)
    files = sorted(p for p in (ROOT / 'shaders').rglob('*') if p.is_file())
    files.append(ROOT / 'LICENSE')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for path in files:
            info = zipfile.ZipInfo(path.relative_to(ROOT).as_posix(), FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, path.read_bytes())
    return out


def main():
    props = properties()
    if '--notes' in sys.argv[1:]:
        notes = ROOT / 'build' / 'release-notes.md'
        notes.parent.mkdir(exist_ok=True)
        notes.write_text(changelog_section(props['pack_version']), encoding='utf-8')
    print(build(props))


if __name__ == '__main__':
    main()
