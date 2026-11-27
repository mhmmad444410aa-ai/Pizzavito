import pathlib, sys, zipfile
apk = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(apk) as archive:
    files = set(archive.namelist())
    assert archive.testzip() is None, "Corrupted APK entry"
    for abi in ("arm64-v8a", "armeabi-v7a"):
        assert f"lib/{abi}/libgodot_android.so" in files, f"Missing Godot library: {abi}"
    assert "AndroidManifest.xml" in files, "Missing manifest"
    assert "classes.dex" in files, "Missing Android runtime"
print(f"Verified APK archive, Android runtime and both native architectures: {apk.name}")
