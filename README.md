# libtdjson

[![Version](https://img.shields.io/cocoapods/v/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![License](https://img.shields.io/cocoapods/l/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)
[![Platform](https://img.shields.io/cocoapods/p/libtdjson.svg?style=flat)](https://cocoapods.org/pods/libtdjson)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

libtdjson is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'libtdjson'
```

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
