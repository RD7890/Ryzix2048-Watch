#!/usr/bin/env python3
"""Inject the permanent release signing config into the generated Gradle file."""
import pathlib, re, sys

kts = pathlib.Path('android/app/build.gradle.kts')
groovy = pathlib.Path('android/app/build.gradle')
path = kts if kts.exists() else groovy
src = path.read_text()

if path is kts:
    header = (
        'import java.util.Properties\n'
        'import java.io.FileInputStream\n\n'
        'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
    )
    signing = (
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '            storePassword = keystoreProperties["storePassword"] as String\n'
        '        }\n'
        '    }\n\n'
    )
    debug_ref = 'signingConfig = signingConfigs.getByName("debug")'
    release_ref = 'signingConfig = signingConfigs.getByName("release")'
else:
    header = (
        'def keystoreProperties = new Properties()\n'
        'def keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
    )
    signing = (
        '    signingConfigs {\n'
        '        release {\n'
        "            keyAlias keystoreProperties['keyAlias']\n"
        "            keyPassword keystoreProperties['keyPassword']\n"
        "            storeFile file(keystoreProperties['storeFile'])\n"
        "            storePassword keystoreProperties['storePassword']\n"
        '        }\n'
        '    }\n\n'
    )
    debug_ref = 'signingConfig signingConfigs.debug'
    release_ref = 'signingConfig signingConfigs.release'

# Header must come AFTER the plugins {} block (Gradle rule).
m = re.search(r'plugins \{.*?\n\}\n', src, re.S)
if m:
    src = src[:m.end()] + '\n' + header + src[m.end():]
else:
    src = header + src
if '    buildTypes {' not in src:
    print('ERROR: buildTypes block not found', file=sys.stderr)
    sys.exit(1)
src = src.replace('    buildTypes {', signing + '    buildTypes {', 1)
if debug_ref in src:
    src = src.replace(debug_ref, release_ref)
else:
    # Only touch the release block INSIDE buildTypes.
    m = re.search(r'buildTypes \{\s*\n\s*release \{', src)
    if not m:
        print('ERROR: buildTypes release block not found', file=sys.stderr)
        sys.exit(1)
    src = src[:m.end()] + '\n            ' + release_ref + src[m.end():]
path.write_text(src)
print(src)
