# Pizzavito: Pizza Maker 3D
Godot 4.5.1 landscape Android vertical slice, package com.mhmmad.pizzavito.
Ten recipe challenges across two kitchen themes, four interactive stages. No ads, analytics, music, people or animals.
Run python3 tools/fetch_assets.py, then import project in Godot. The CI downloads selected CC0 assets, imports, smoke-tests and exports a signed test APK. Production signing is optional via repository secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEY_ALIAS, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD. Keep the production key permanently backed up. No production key is generated in CI. See Actions logs for actual results.
This is an unvalidated vertical slice, not a full game or a store-ready build. Missing: remaining six modes, full 120 levels, polished animation and sound, eight worlds, complete accessibility/device testing and publication assets. UI translations are inline; system menus may still differ. See THIRD_PARTY_LICENSES.md.

## Visual and gameplay revision 1.0.1
Rebalanced lighting, expanded original KayKit props, stage-specific camera, textured toppings, rolling pin, spatial sauce strokes, directional slice validation, packaging animation, free mode and original non-musical UI SFX. Still a vertical slice; device appearance, touch flow and production quality have not been validated. No claims of full 120-stage release.
