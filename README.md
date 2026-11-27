# Pizzavito: Pizza Maker 3D — Rebuild 2.0.0
New 2.5D touch-first cooking studio with original illustrated vector art, separate home, recipe book, kitchen, settings, ingredient gallery and result screens. 50 named recipe variants with five dough silhouettes, two sauces, nine ingredients, variable cut targets, four illustrated kitchens, spatial sauce coverage, drag/tap toppings and oven timing. Ingredient gallery uses imported original CC0 3D assets. Offline, no music or ads. The old prototype remains in git history.
CI verifies asset import, six stage transitions, all screens, APK native libraries and signature. This is a new test milestone, not a verified production release. Real device visual review, performance, touch accessibility, permanent release key and the remaining original requested gameplay modes are still outstanding. 
# Pizzavito: Pizza Maker 3D
Godot 4.5.1 landscape Android vertical slice, package com.mhmmad.pizzavito.
Ten recipe challenges across two kitchen themes, four interactive stages. No ads, analytics, music, people or animals.
Run python3 tools/fetch_assets.py, then import project in Godot. The CI downloads selected CC0 assets, imports, smoke-tests and exports a signed test APK. Production signing is optional via repository secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEY_ALIAS, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD. Keep the production key permanently backed up. No production key is generated in CI. See Actions logs for actual results.
This is an unvalidated vertical slice, not a full game or a store-ready build. Missing: remaining six modes, full 120 levels, polished animation and sound, eight worlds, complete accessibility/device testing and publication assets. UI translations are inline; system menus may still differ. See THIRD_PARTY_LICENSES.md.

## Visual and gameplay revision 1.0.1
Rebalanced lighting, expanded original KayKit props, stage-specific camera, textured toppings, rolling pin, spatial sauce strokes, directional slice validation, packaging animation, free mode and original non-musical UI SFX. Still a vertical slice; device appearance, touch flow and production quality have not been validated. No claims of full 120-stage release.

## 1.1.0 recipe and visual overhaul
30 selectable recipes, five dough profiles, nine ingredient tools including sauce, persistent completion, spatial collision checks for toppings, separate animated pizza slices, guided cutting and optional real wood/UI assets. Source downloads and actual usage are verified in build logs; network-dependent optional assets fall back to original materials. Device rendering and the final APK size remain to be verified. Not all original ten modes are implemented.

## 1.2.0 market and visual rebuild
Ingredient shopping before cooking, 30 illustrated recipe cards, visible ingredient thumbnails (Kenney previews when available), original texture maps and launcher icon, layered toppings and cheese, revised warm cream controls, four pinned Quaternius CC0 crop meshes. The market uses a distinct 3D scene. This revision needs a successful CI run and visual acceptance on a real device; it is not a completed commercial title.
