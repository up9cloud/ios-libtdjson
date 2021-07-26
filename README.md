# ios-libtdjson

[![Version](https://img.shields.io/cocoapods/v/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![License](https://img.shields.io/cocoapods/l/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![Platform](https://img.shields.io/cocoapods/p/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)

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

> Use as module

Because this pod **only** provide .dylib files (to prevent module name conflicts and keep it simplest!), if you want to use it as module (e.q. on iOS with swift), you **have to** add some necessary files:

- Download example `headers` and `module.modulemap`

```bash
curl -SLO https://github.com/up9cloud/ios-libtdjson/releases/download/v0.2.0/cocoapod_include.tar.gz
mkdir include
tar xzf cocoapod_include.tar.gz -C include

# Edit files to whatever you want, e.q. change the module name or remove export symbols you don't need
```

- Add include path and link lib, e.q.

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

Download prebuilt files from `Release`, then do whatever you want.

## Q&A

> An error was encountered processing the command (domain=FBSOpenApplicationServiceErrorDomain,code=1):

The app will crash if identification name of .dylib isn't correct

```bash
# check id
otool -D libtdjson.dylib

# fix id
install_name_tool -id @rpath/libtdjson.dylib libtdjson.dylib
```

## TODO

- [ ] Support [Carthage](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile)
- [ ] Support M1 (Apple Silicon), see [this](https://github.com/tdlib/td/pull/1620)
