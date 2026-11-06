#!/usr/bin/env python3
"""Make the generated Android manifest watch-friendly and verify the package id.

* launcher label            -> "2048"
* <uses-feature type.watch> -> required=false (installs on watches AND phones)
* standalone Wear OS flag   -> app runs without a companion phone app
"""
import pathlib
import re
import sys

PKG = 'com.ryzix2048.watch'

manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
src = manifest.read_text()

src = re.sub(r'android:label="[^"]*"', 'android:label="2048"', src, count=1)

if 'android.hardware.type.watch' not in src:
    src = src.replace(
        '<application',
        '<uses-feature android:name="android.hardware.type.watch" '
        'android:required="false" />\n    <application',
        1,
    )

if 'com.google.android.wearable.standalone' not in src:
    m = re.search(r'<application[^>]*>', src, re.S)
    if not m:
        sys.exit('ERROR: <application> tag not found in manifest')
    src = (
        src[: m.end()]
        + '\n        <meta-data android:name="com.google.android.wearable.standalone"'
        ' android:value="true" />'
        + src[m.end():]
    )

manifest.write_text(src)
print(src)

# --- verify the package / applicationId really is com.ryzix2048.watch --------
gradle = None
for name in ('build.gradle.kts', 'build.gradle'):
    p = pathlib.Path('android/app') / name
    if p.exists():
        gradle = p.read_text()
        break
if gradle is None:
    sys.exit('ERROR: android/app/build.gradle(.kts) not found')

for key in ('applicationId', 'namespace'):
    if not re.search(key + r'\s*=?\s*"' + re.escape(PKG) + '"', gradle):
        sys.exit(f'ERROR: {key} is not {PKG}')
print(f'OK: applicationId and namespace are {PKG}')
