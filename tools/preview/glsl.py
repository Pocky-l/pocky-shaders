"""Helpers for the offline shader tools: include resolution like Iris and an offscreen GL context."""
import pathlib
import re

SHADERS = pathlib.Path(__file__).resolve().parents[2] / 'src' / 'main' / 'resources' / 'shaderpack' / 'shaders'
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')


def expand(source, base=SHADERS, seen=None):
    """Inline #include directives ("/x" is relative to the shaders root, "x" to the including file)."""
    seen = set() if seen is None else seen
    out = []
    for line in source.splitlines():
        m = INCLUDE.match(line)
        if not m:
            out.append(line)
            continue
        name = m.group(1)
        path = (SHADERS / name.lstrip('/')) if name.startswith('/') else (base / name)
        path = path.resolve()
        if path in seen:
            continue
        seen.add(path)
        out.append(expand(path.read_text(encoding='utf-8'), path.parent, seen))
    return '\n'.join(out)


def program_source(path, defines=(), version='#version 330 compatibility'):
    body = expand(pathlib.Path(path).read_text(encoding='utf-8'), pathlib.Path(path).parent)
    head = [version] + [f'#define {d}' for d in defines]
    return '\n'.join(head) + '\n#line 1\n' + body
