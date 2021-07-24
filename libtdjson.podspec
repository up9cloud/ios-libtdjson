#
# Be sure to run `pod lib lint libtdjson.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'libtdjson'
  s.version          = '0.1.0'
  s.summary          = 'TDLib JSON interface, shared lib (libtdjson.dylib)'
  s.homepage         = 'https://github.com/up9cloud/ios-libtdjson'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'up9cloud' => '8325632+up9cloud@users.noreply.github.com' }
  s.source           = { :http => 'https://github.com/up9cloud/ios-libtdjson/releases/download/v0.1.0/cocoapod.tar.gz' }

  s.osx.vendored_libraries = 'dylibs/macOS/libtdjson.dylib'
  s.osx.deployment_target = '10.11'
  s.ios.vendored_libraries = 'dylibs/iOS/libtdjson.dylib'
  s.ios.deployment_target = '9.0'
end
