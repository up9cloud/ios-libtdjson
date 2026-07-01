# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is a **packaging/distribution repo**, not a library source repo. It builds [TDLib](https://github.com/tdlib/td)'s `libtdjson` shared library for Apple platforms and ships the result as a CocoaPods pod (`libtdjson` + `flutter_libtdjson`) and as `libtdjson.xcframework`. The actual C++ library source is `tdlib/td` upstream — checked out into `./td/` by the build script at a pinned commit.

Only macOS (x86_64, arm64) and iOS (arm64 device, x86_64+arm64 simulator) are actually built. The README's "Supported architectures" table shows the full Apple matrix; everything not marked ✅/⛔ is intentionally not built. iOS device builds are dylibs and are blocked from the App Store (per Apple TN2435) — this is a known/accepted limitation, not a bug.

## Build

`./build.sh` is the single entry point. It:

1. Clones `tdlib/td` into `./td/` at a hardcoded commit hash if not already present.
2. Downloads prebuilt OpenSSL (krzyzanowskim/OpenSSL release) into `./install/openssl/` if not already present, then renames Apple's SDK folder names (`iphoneos` → `iOS`, `iphonesimulator` → `iOS-simulator`, `macosx` → `macOS`).
3. For each platform (default: `macOS iOS`), runs CMake → builds `tdjson` and `tdjson_static` targets → installs into `./install/tdjson/<platform>[-simulator]/`.
4. Fixes the dylib install-name to `@rpath/libtdjson.dylib` (otherwise apps crash with FBSOpenApplicationServiceErrorDomain code=1).
5. For each platform/simulator, runs `libtool -static` to merge every tdlib static archive (`libtd*.a` — tdcore/tdactor/tddb/tdnet/tdutils/tdsqlite/tdapi/tdjson_private/tdclient + tdjson_static) PLUS OpenSSL's `libssl.a` + `libcrypto.a` into a single self-contained `libtdjson.a` inside `$install_dir/combined/`. This matches what the dylib has internally — without this merge, `libtdjson_static.a` alone has unresolved symbols for every tdlib subsystem and for OpenSSL.
6. Bundles per-platform dylibs into `./libtdjson.xcframework` AND per-platform merged `libtdjson.a` archives (with headers) into `./libtdjson-static.xcframework` via two `xcodebuild -create-xcframework` calls. Both xcframeworks expose the same `td_json_client_*` / `td_*` symbols — consumers pick whichever they need; the symbols match so source code is identical either way.

Build a single platform: `./build.sh macOS` or `./build.sh iOS`.

The script requires `gperf cmake coreutils` (CI installs via Homebrew and puts `gnubin` on PATH — `grealpath` from coreutils is used).

## Release / publish flow

Releases are tag-driven. `.github/workflows/main.yml` runs on any pushed tag: it builds, packages five tarballs (`install.tar.gz`, `libtdjson.xcframework.tar.gz`, `libtdjson-static.xcframework.tar.gz`, `cocoapod.tar.gz` — contains BOTH xcframeworks plus LICENSE, `cocoapod_modulemap.tar.gz`), creates a GitHub Release with them as assets, then runs `pod trunk push` for both podspecs. The podspecs read the version from `GITHUB_REF` (the tag), and `s.source` points at `https://github.com/up9cloud/ios-libtdjson/releases/download/v<version>/cocoapod.tar.gz` — so the release assets must exist before pod trunk push can succeed.

To bump TDLib version: edit the `git checkout <hash>` line in `build.sh`, update the version table in `README.md`, commit (`bump td to vx.x.x`), tag `vx.x.x`, push with tags. The `vx.x.x` tag is the published pod version. README's "Dev memo" section has full recovery procedures for failed CI / failed pod publish / reverting a tag.

## Module map for Swift users

`module.modulemap` exposes `td_json_client.h` as Swift module `libtdjson`. CI repackages it into `cocoapod_modulemap.tar.gz` along with the relevant headers from `install/tdjson/iOS/include/td/telegram/`. Downstream Swift users have to download and wire this themselves (see README "Use it as module" section) — the pod itself vends the xcframeworks (and the static one carries headers); no separate headers shipped beyond that.

## Podspec platform defaults

Both `libtdjson.podspec` and `flutter_libtdjson.podspec` ship both xcframeworks inside `cocoapod.tar.gz`, but `vendored_frameworks` is platform-scoped: `s.osx.vendored_frameworks = 'libtdjson.xcframework'` and `s.ios.vendored_frameworks = 'libtdjson-static.xcframework'`. This matches what each platform can actually ship: iOS App Store rejects custom dylibs (TN2435), macOS doesn't care. `s.preserve_paths` lists both so the unused xcframework still ends up on disk for consumers who want to override per-platform.

`example/JsonClient.swift` shows the expected Swift wrapper pattern over the C `td_json_client_*` / `td_*` functions.

## Things not to touch casually

- The pinned TDLib commit hash in `build.sh` — bumping it is the whole point of a release.
- OpenSSL version (`v_tag=3.1.5004`) — the comment explains why beeware's Python-Apple-support OpenSSL was rejected (arch mismatch errors).
- The `install_name_tool -id @rpath/libtdjson.dylib` step — removing it breaks consumer apps at launch.
- `build/`, `install/`, `td/`, `libtdjson.xcframework/`, `*.tar.gz`, `tmp/` are all gitignored build artifacts. The `libtdjson.xcframework/` directory in the tree is a leftover from before it was gitignored; do not edit its contents.
