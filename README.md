# ios-libtdjson

[![Version](https://img.shields.io/cocoapods/v/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![License](https://img.shields.io/cocoapods/l/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![Platform](https://img.shields.io/cocoapods/p/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)

## Lib versions

|  pod   |                                        tdlib                                          |
| ------ | ------------------------------------------------------------------------------------- |
| 1.8.65 | [1.8.65](https://github.com/tdlib/td/commit/a8f21f5230172634becc1739050ef23ecd6ea291) |
| 1.8.52 | [1.8.52](https://github.com/tdlib/td/commit/a03a90470d6fca9a5a3db747ba3f3e4a465b5fe7) |
| 0.4.3  | [1.8.47](https://github.com/tdlib/td/commit/a03a90470d6fca9a5a3db747ba3f3e4a465b5fe7) |
| 0.4.2  | [1.8.31](https://github.com/tdlib/td/commit/8f19c751dc296cedb9a921badb7a02a8c0cb1aeb) |
| 0.4.1  | [1.8.30](https://github.com/tdlib/td/commit/fab354add5a257a8121a4a7f1ff6b1b9fa9a9073) |
| 0.3.0  | [1.8.7](https://github.com/tdlib/td/commit/a7a17b34b3c8fd3f7f6295f152746beb68f34d83)  |
| 0.2.2  | [1.8.1](https://github.com/tdlib/td/commit/92c2a9c4e521df720abeaa9872e1c2b797d5c93f)  |
| 0.2.1  | [1.7.9](https://github.com/tdlib/td/commit/7d41d9eaa58a6e0927806283252dc9e74eda5512)  |
| 0.2.0  | [1.7.0](https://github.com/tdlib/td/tree/v1.7.0)                                      |

Notes:

- Since **v1.8.52**, the git tag / pod version matches the tdlib version it wraps (before that, the pod used its own `0.x.y` numbering).
- Since **v1.8.65**, releases ship a static `libtdjson.a` (via `libtdjson-static.xcframework`) alongside the dylib — see [dylib vs static .a](#dylib-vs-static-a).

## Supported architectures

|      Platform      | Architecture |     |
| ------------------ | ------------ | --- |
| iOS                | armv7        | ❌   |
|                    | armv7s       | ❌   |
|                    | arm64        | ✅⛔ |
| iOS simulator      | i386         | ❌   |
|                    | x86_64       | ✅⛔ |
|                    | arm64 (M1↑)  | ✅⛔ |
| macOS              | i386         | ❌   |
|                    | x86_64       | ✅   |
|                    | arm64 (M1↑)  | ✅   |
| watchOS            | armv7k       | ❌   |
|                    | arm64_32     | ❌   |
|                    | arm64        | ❌   |
| watchOS simulator  | x86_64       | ❌   |
|                    | arm64        | ❌   |
| tvOS               | arm64        | ❌   |
| tvOS simulator     | x86_64       | ❌   |
|                    | arm64        | ❌   |
| visionOS           | arm64        | ❌   |
| visionOS simulator | x86_64       | ❌   |
|                    | arm64        | ❌   |

✅ marks slices that are actually built (the static `.a` works on all of them; the dylib is included too, subject to the caveats below).

⛔ marks the dylib caveats that apply to iOS:

- **App Store**: iOS apps that ship a custom `.dylib` are rejected. Link the static `libtdjson.a` (from `libtdjson-static.xcframework`) instead. See [TN2435](https://developer.apple.com/library/archive/technotes/tn2435/_index.html#//apple_ref/doc/uid/DTS40017543-CH1-PROJ_CONFIG-APPS_WITH_DEPENDENCIES_BETWEEN_FRAMEWORKS).
- **iOS simulator**: the dylib runs, but it isn't copied into the built `.app`'s `Frameworks/` automatically — you need to symlink it in yourself. Example (Flutter):

  ```bash
  ln -s $(pwd)/build/ios/Debug-iphonesimulator/XCFrameworkIntermediates/flutter_libtdjson/libtdjson.dylib \
    ~/Library/Developer/CoreSimulator/Devices/<DEVICE-UUID>/data/Containers/Bundle/Application/<APP-UUID>/Runner.app/Frameworks/libtdjson.dylib
  ```

## Installation

### CocoaPods

libtdjson is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'libtdjson'
```

or add it to your .podspec file:

```ruby
Pod::Spec.new do |s|
  s.dependency 'libtdjson'
end
```

#### dylib vs static .a

Starting from v1.8.65, the pod ships **both** variants:

| xcframework                     | Contents                                                                                         |
| ------------------------------- | ------------------------------------------------------------------------------------------------ |
| `libtdjson.xcframework`         | `libtdjson.dylib` — dynamic library, OpenSSL statically linked inside                            |
| `libtdjson-static.xcframework`  | `libtdjson.a` — single merged archive of all tdlib `.a` files + `libssl.a` + `libcrypto.a`       |

The pod links the right one for you automatically:

- **macOS** → `libtdjson.dylib`
- **iOS** → `libtdjson.a` (App Store rejects custom dylibs, see [TN2435](https://developer.apple.com/library/archive/technotes/tn2435/_index.html#//apple_ref/doc/uid/DTS40017543-CH1-PROJ_CONFIG-APPS_WITH_DEPENDENCIES_BETWEEN_FRAMEWORKS))

Either way you `import libtdjson` (or include `td_json_client.h`) the same way — the `td_json_client_*` / `td_*` symbols are identical. No code changes needed when switching.

##### Overriding the default

Both xcframeworks ship inside the pod (via `cocoapod.tar.gz`), so if the default doesn't fit — e.g. you want the dylib on iOS simulator for debugging — the simplest path is to skip the pod for that platform and drag the desired `.xcframework` in by hand from the [release assets](#manually).

### Use it as module (iOS, swift)

The pod itself doesn't ship a `module.modulemap` (to prevent module name conflicts and keep the pod as small as possible), so if you want to use it as a Swift module you **have to** add some necessary files:

- Download example `headers` and `module.modulemap`

```bash
curl -SLO https://github.com/up9cloud/ios-libtdjson/releases/download/v0.2.2/cocoapod_modulemap.tar.gz
mkdir include
tar xzf cocoapod_modulemap.tar.gz -C include

# Edit files to whatever you want, e.g. change the module name or remove export symbols you don't need
```

- Add include path and link lib, e.g.

```ruby
Pod::Spec.new do |s|
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '${PODS_TARGET_SRCROOT}/include',
    'OTHER_LDFLAGS' => '-ltdjson',
  }
end
```

- Use it

```swift
import libtdjson
func create() -> Int {
    return Int(bitPattern: libtdjson.td_json_client_create()!)
}
// ... (more usages at ./example/*)
```

### Carthage

TODO:

### Manually

Download prebuilt files from `Release`:

- `libtdjson.xcframework.tar.gz` — dynamic (`libtdjson.dylib`, OpenSSL inside)
- `libtdjson-static.xcframework.tar.gz` — static (`libtdjson.a`, every tdlib subsystem + OpenSSL merged into one archive)
- `install.tar.gz` — both, plus per-platform unpackaged `.dylib` / individual `.a` files / headers (if you want to mix and match yourself)

Pick whichever matches your linking strategy and drag the `.xcframework` into your Xcode project. Nothing else to link — both are self-contained.

## Q&A

> An error was encountered processing the command (domain=FBSOpenApplicationServiceErrorDomain,code=1):

(Dylib only — does not apply to the static `.a`.) The app will crash if the install name of the `.dylib` isn't set correctly.

```bash
# check id
otool -D libtdjson.dylib

# fix id
install_name_tool -id @rpath/libtdjson.dylib libtdjson.dylib
```

## TODO

- [x] Package static lib for App Store (since v1.8.65, see `libtdjson-static.xcframework`)
- [ ] Support [Carthage](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile)
- [x] Support M1 (Apple Silicon) - migrate to XCFramework, see [PR 1620](https://github.com/tdlib/td/pull/1620)

## Dev memo

### Bump the TDLib version

- Modify the version for git checkout in `./build.sh`
- Update the `Lib versions` part in `./README.md`
- Git commit (message example: `bump td to vx.x.x`)
- Git add tag (`git tag vx.x.x`, the tag version should be the version on cocoapod)
- Push with tags (`git push && git push --tags`)
- Wait for CI task

> If the CI build failed

> `[!] Authentication token is invalid or unverified. Either verify it with the email that was sent or register a new session.`

```bash
# get user info: https://trunk.cocoapods.org/api/v1/pods/libtdjson
pod trunk register <email> '<name>'
pod trunk me
cat ~/.netrc | grep -A 2 trunk.cocoapods.org # get token (password)
# update github secret
```

> Manually update the pod, if publishing to the pod fails.

```bash
export GITHUB_REF=refs/tags/<the version tag>
pod trunk push --allow-warnings libtdjson.podspec
pod trunk push --allow-warnings flutter_libtdjson.podspec
```

> Find pod info

```bash
pod trunk info libtdjson
```

> what if need to revert the tag...

```bash
version=<the version tag>
git push --delete origin $version
git tag -d $version
git add .
git commit -m "..."
git tag $version
git push && git push --tags
```
