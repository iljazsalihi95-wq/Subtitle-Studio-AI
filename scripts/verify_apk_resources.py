"""Verify actual APK pixels, ABI and optional approved illustrations."""
from pathlib import Path
import io
import zipfile
from PIL import Image, ImageChops

apk = Path('build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk')
with zipfile.ZipFile(apk) as archive:
    bad_entry = archive.testzip()
    assert bad_entry is None, f'Corrupt APK ZIP entry: {bad_entry}'
    names = archive.namelist()
    assert len(names) == len(set(names)), 'Duplicate APK entries are not allowed'
    assert all(not name.startswith('/') and '..' not in name.split('/') and '\\' not in name for name in names), 'Unsafe APK archive entry path'
    assert 'AndroidManifest.xml' in names, 'Compiled Android manifest missing'\n    assert 'resources.arsc' in names, 'Compiled Android resources missing'\n    assert 'classes.dex' in names, 'Android executable bytecode missing'
    assert any(name.startswith('assets/flutter_assets/') for name in names), 'Flutter app assets missing'
    # Reject accidental packaging of private configuration or signing material.
    private_names = {'google-services.json', 'googleservice-info.plist', 'key.properties',
                     'credentials.json', 'service-account.json'}
    private_suffixes = ('.jks', '.keystore', '.p12', '.pfx', '.pem', '.key')
    for entry in names:
        basename = entry.rsplit('/', 1)[-1].lower()
        assert not (basename == '.env' or basename.startswith('.env.')
                    or basename in private_names or basename.endswith(private_suffixes)), (
            f'Potential private configuration packaged in APK: {entry}')
    assert 'lib/arm64-v8a/libflutter.so' in names, 'ARM64 Flutter runtime missing'
    assert not any(name.startswith(('lib/x86', 'lib/armeabi')) for name in names), 'Unexpected non-ARM64 runtime'
    icons = [name for name in names if name.startswith('res/') and name.endswith('/ic_launcher.png')]
    assert len(icons) == 5, f'Expected exactly five launcher icons, found {len(icons)}'
    expected = {}
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for density, size in densities.items():
        path = Path(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
        assert path.is_file(), f'Missing source launcher: {path}'
        with Image.open(path) as image:
            assert image.size == (size, size), f'Incorrect source launcher size: {path}'
            expected[(size, size)] = image.convert('RGBA').copy()
    found = set()
    for name in icons:
        with Image.open(io.BytesIO(archive.read(name))) as image:
            actual = image.convert('RGBA')
            assert actual.size in expected, f'Unexpected launcher size: {name}'
            assert ImageChops.difference(actual, expected[actual.size]).getbbox() is None, f'Launcher pixels differ: {name}'
            found.add(actual.size)
    assert found == set(expected), 'APK launcher densities do not match generated artwork'
    frames = sorted(Path('assets/story').glob('frame_*.jpg'))
    bundled_frames = sorted(name for name in names if name.startswith('assets/flutter_assets/assets/story/') and name.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')))
    assert bundled_frames == sorted('assets/flutter_assets/' + frame.as_posix() for frame in frames), 'Unexpected or missing bundled story images'
    for frame in frames:
        name = 'assets/flutter_assets/' + frame.as_posix()
        assert archive.read(name) == frame.read_bytes(), f'Illustration missing/changed: {frame.name}'
    print(f'APK verified: ARM64, {len(found)} matching launcher sizes, {len(frames)} original illustrations')
