#!/usr/bin/env python3
"""Push the whole working tree to GitHub as ONE commit (never parallel)."""
import os, sys, json, base64, urllib.request, urllib.error, pathlib

T = os.environ['GITHUB_PAT']
OWNER = 'RD7890'
REPO = 'Ryzix2048-Watch'
SKIP = {'.git', 'build', '.dart_tool', 'android', 'out', '__pycache__'}


def api(method, url, data=None):
    req = urllib.request.Request(
        "https://api.github.com" + url, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'Authorization': f'Bearer {T}',
                 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'ryzix', 'Content-Type': 'application/json'})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=90).read() or b'{}')
    except urllib.error.HTTPError as e:
        print(method, url, e.code, e.read()[:500].decode())
        raise


def main(msg):
    root = pathlib.Path(os.path.abspath(__file__)).parent
    files = [p for p in sorted(root.rglob('*'))
             if p.is_file() and not any(s in p.relative_to(root).parts for s in SKIP)]
    tree = []
    for p in files:
        sha = api('POST', f'/repos/{OWNER}/{REPO}/git/blobs',
                  {'content': base64.b64encode(p.read_bytes()).decode(),
                   'encoding': 'base64'})['sha']
        tree.append({'path': str(p.relative_to(root)).replace('\\', '/'),
                     'mode': '100644', 'type': 'blob', 'sha': sha})
    try:
        parent = api('GET', f'/repos/{OWNER}/{REPO}/git/ref/heads/main')['object']['sha']
        parents = [parent]
    except urllib.error.HTTPError:
        parents = []
    t = api('POST', f'/repos/{OWNER}/{REPO}/git/trees', {'tree': tree})['sha']
    c = api('POST', f'/repos/{OWNER}/{REPO}/git/commits',
            {'message': msg, 'tree': t, 'parents': parents})
    if parents:
        api('PATCH', f'/repos/{OWNER}/{REPO}/git/refs/heads/main',
            {'sha': c['sha'], 'force': True})
    else:
        api('POST', f'/repos/{OWNER}/{REPO}/git/refs',
            {'ref': 'refs/heads/main', 'sha': c['sha']})
    print('pushed', c['sha'], len(files), 'files')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'update')
