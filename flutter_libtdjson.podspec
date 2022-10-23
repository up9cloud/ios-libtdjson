#
# Be sure to run `pod lib lint libtdjson.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  _VERSION = ENV['GITHUB_REF']&.start_with?("refs/tags") ? ENV['GITHUB_REF'].sub(/^refs\/tags\/v/, '') : '0.1.0'

  s.name             = 'flutter_libtdjson'
  s.version          = _VERSION
  s.summary          = 'It\'s same as pod `libtdjson`, just for preventing name conflict'
  s.homepage         = 'https://github.com/up9cloud/ios-libtdjson'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'up9cloud' => '8325632+up9cloud@users.noreply.github.com' }
  s.source           = { :http => "https://github.com/up9cloud/ios-libtdjson/releases/download/v#{_VERSION}/cocoapod.tar.gz" }

  s.vendored_frameworks = 'libtdjson.xcframework'
  s.osx.deployment_target = '10.11'
  s.ios.deployment_target = '9.0'
  s.ios.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
