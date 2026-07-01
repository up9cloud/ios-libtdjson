#
# Be sure to run `pod lib lint libtdjson.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  _VERSION = ENV['GITHUB_REF']&.start_with?("refs/tags") ? ENV['GITHUB_REF'].sub(/^refs\/tags\/v/, '') : '0.1.0'

  s.name             = 'libtdjson'
  s.version          = _VERSION
  s.summary          = 'TDLib JSON interface (libtdjson.dylib for macOS, libtdjson.a for iOS)'
  s.homepage         = 'https://github.com/up9cloud/ios-libtdjson'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'up9cloud' => '8325632+up9cloud@users.noreply.github.com' }
  s.source           = { :http => "https://github.com/up9cloud/ios-libtdjson/releases/download/v#{_VERSION}/cocoapod.tar.gz" }

  # Platform defaults match what each platform can actually ship:
  #   macOS → libtdjson.dylib (works out of the box)
  #   iOS   → libtdjson.a (App Store rejects custom dylibs, see TN2435)
  # Both xcframeworks are downloaded with the pod (via the cocoapod.tar.gz
  # source), so consumers can override per platform by overriding
  # vendored_frameworks in their own Podfile / podspec. See README for how.
  s.osx.vendored_frameworks = 'libtdjson.xcframework'
  s.ios.vendored_frameworks = 'libtdjson-static.xcframework'
  s.preserve_paths          = ['libtdjson.xcframework', 'libtdjson-static.xcframework']
  # Bumped to the minimums Xcode still accepts (Xcode 15+ range: macOS 10.13+,
  # iOS 12.0+). The compiled binaries themselves target lower — these are
  # just the floor CocoaPods advertises to consumers.
  s.osx.deployment_target = '10.13'
  s.ios.deployment_target = '12.0'
end
