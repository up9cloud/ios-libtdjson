#!/bin/bash -e

# See https://github.com/tdlib/td/blob/master/example/ios/build.sh

__DIR__="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# https://github.com/beeware/Python-Apple-support/releases/download/3.9-b3/Python-3.9-$platform-support.b3.tar.gz will Cause error: ...libOpenSSL.a(bss_mem.o), building for iOS, but linking in object file (.../libOpenSSL.a(bss_mem.o)) built for macOS, for architecture arm64
download_prebuilt_openssl() {
	local install_root_dir="$1"
	local v_tag=3.1.5004
	local f_name=OpenSSL.tar.gz
	curl -SL https://github.com/krzyzanowskim/OpenSSL/archive/refs/tags/${v_tag}.tar.gz -o $f_name
	tar xzf $f_name
	# The output folder name should be OpenSSL-${v_tag}
	mkdir -p $install_root_dir
	mv OpenSSL-${v_tag} $install_root_dir/openssl
	rm $f_name

	# standardize the folder name
	# mv $install_root_dir/openssl/appletvos $install_root_dir/openssl/tvOS
	# mv $install_root_dir/openssl/appletvsimulator $install_root_dir/openssl/tvOS-simulator
	mv $install_root_dir/openssl/iphoneos $install_root_dir/openssl/iOS
	mv $install_root_dir/openssl/iphonesimulator $install_root_dir/openssl/iOS-simulator
	mv $install_root_dir/openssl/macosx $install_root_dir/openssl/macOS
	# mv $install_root_dir/openssl/macosx_catalyst $install_root_dir/openssl/macOS_catalyst
	# mv $install_root_dir/openssl/visionos $install_root_dir/openssl/visionOS
	# mv $install_root_dir/openssl/visionsimulator $install_root_dir/openssl/visionOS-simulator
}
download_td_source() {
	cd $__DIR__
	git clone https://github.com/tdlib/td.git
	cd td
	# How to get the hash if there is no version tag:
	# - Goto https://github.com/tdlib/td/blame/master/CMakeLists.txt
	# - Check the version from the line: `project(TDLib VERSION <version>...`
	# - Copy version and paste to following:
	# git checkout tags/v1.8.52
	# - Click the commit link
	# - Copy the commit hash from the browser url link (e.q. https://github.com/tdlib/td/commit/<hash>) and paste to following:
	git checkout 4269f54e16b9cf564efc2db5bcd29743a2eec6ee
	cd ..
}

BUILD_ROOT_DIR="$__DIR__/build"
INSTALL_ROOT_DIR="$__DIR__/install"
ARCHIVES_ROOT_DIR="$__DIR__/archives"
TD_DIR="$__DIR__/td"

# cleanup all
# rm -fr $BUILD_ROOT_DIR
# rm -fr $INSTALL_ROOT_DIR
# rm -fr $ARCHIVES_ROOT_DIR
# rm -fr $TD_DIR

# prepare
if [ ! -d "$TD_DIR" ]; then
	download_td_source
fi
if [ ! -d "$INSTALL_ROOT_DIR/openssl" ]; then
	download_prebuilt_openssl $INSTALL_ROOT_DIR
fi

# build, see https://github.com/tdlib/td/tree/master/example/ios
if [ -z "$1" ]; then
	# platforms="macOS iOS watchOS tvOS visionOS"
	platforms="macOS iOS"
	# Need to generate some files if we don't build macOS first, see https://github.com/tdlib/td/issues/1077#issuecomment-640056388
	# if [ ! -d "$BUILD_ROOT_DIR/prepare_cross_compiling" ]; then
	# 	mkdir -p $BUILD_ROOT_DIR/prepare_cross_compiling
	# 	cd $BUILD_ROOT_DIR/prepare_cross_compiling

	# 	cmake $TD_DIR || exit 1
	# 	cmake --build . --target prepare_cross_compiling || exit 1
	# fi
else
	platforms="$1"
fi
xcodebuild_more_options=""
for platform in $platforms; do
	if [[ $platform = "macOS" ]]; then
		simulators="0"
		more_options="-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES='x86_64;arm64'"
	else
		simulators="0 1"
		more_options="-DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_TOOLCHAIN_FILE=${TD_DIR}/CMake/iOS.cmake -DCMAKE_MAKE_PROGRAM=make"
	fi
	openssl_install_path="$INSTALL_ROOT_DIR/openssl/${platform}"
	build_dir="$BUILD_ROOT_DIR/${platform}"
	install_dir="$INSTALL_ROOT_DIR/tdjson/${platform}"
	for simulator in $simulators; do
		if [[ $platform = "macOS" ]]; then
			cmake_ios_platform=""
			xcode_platform="OS"
		else
			if [[ $platform = "watchOS" ]]; then
				cmake_ios_platform="WATCH"
			elif [[ $platform = "tvOS" ]]; then
				cmake_ios_platform="TV"
			elif [[ $platform = "visionOS" ]]; then
				cmake_ios_platform="VISION"
			else
				cmake_ios_platform=""
			fi
			xcode_platform=$platform
			if [[ $simulator = "0" ]]; then
				cmake_ios_platform="${cmake_ios_platform}OS"
			else
				cmake_ios_platform="${cmake_ios_platform}SIMULATOR"
				xcode_platform="${cmake_ios_platform} Simulator"

				openssl_install_path="${openssl_install_path}-simulator"
				build_dir="${build_dir}-simulator"
				install_dir="${install_dir}-simulator"
			fi
			more_options="$more_options -DIOS_PLATFORM=${cmake_ios_platform}"
		fi
		openssl_crypto_library="${openssl_install_path}/lib/libcrypto.a"
		openssl_ssl_library="${openssl_install_path}/lib/libssl.a"

		# rm -rf $build_dir $install_dir
		mkdir -p $build_dir $install_dir

		cd $build_dir
		cmake $TD_DIR $more_options \
			-DCMAKE_INSTALL_PREFIX=$install_dir \
			-DOPENSSL_FOUND=1 \
			-DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library} \
			-DOPENSSL_SSL_LIBRARY=${openssl_ssl_library} \
			-DOPENSSL_INCLUDE_DIR=${openssl_install_path}/include \
			-DOPENSSL_LIBRARIES="${openssl_crypto_library};${openssl_ssl_library}" || exit 1
		cmake --build . --target tdjson || exit 1
		cmake --build . --target tdjson_static || exit 1
		cmake --install . || exit 1

		# xcodebuild clean archive \
		# 	-scheme "${SCHEME_NAME}" \
		# 	-configuration "${CONFIGURATION}" \
		# 	-sdk iphoneos \
		# 	-archivePath "${IOS_DEVICE_ARCHIVE_PATH}" \
		# 	-destination generic/platform=iOS \
		# 	SKIP_INSTALL=NO \
		# 	BUILD_LIBRARY_FOR_DISTRIBUTION=YES
		# https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
		# xcodebuild archive \
		# 	-scheme libtdjson \
		# 	-destination "generic/platform=$xcode_platform" \
		# 	-archivePath "$ARCHIVES_ROOT_DIR/libtdjson-${xcode_platform}"
		# xcodebuild_more_options="$xcodebuild_more_options -archive $ARCHIVES_ROOT_DIR/libtdjson-${xcode_platform}.xcarchive -framework libtdjson.framework"

		# for a in $install_dir/lib/*.a; do
		# 	abs_path="$(grealpath "${a}")"
		# 	file $abs_path
		# 	xcodebuild_more_options="$xcodebuild_more_options -library $abs_path -headers $install_dir/include"
		# done
		dylib_path="$install_dir/lib/libtdjson.dylib"
		abs_path="$(grealpath "$dylib_path")"
		if [ -h $dylib_path ]; then
			rm -fr $dylib_path
			mv $abs_path $dylib_path
			install_name_tool -id @rpath/libtdjson.dylib $dylib_path
		fi
		xcodebuild_more_options="$xcodebuild_more_options -library $dylib_path"
	done
done

# What if met the error: Requested but did not find extension point with identifier Xcode.IDEKit.ExtensionSentinelHostApplications for extension Xcode.DebuggerFoundation.AppExtensionHosts.watchOS of plug-in com.apple.dt.IDEWatchSupportCore...
# see:
# - https://apple.stackexchange.com/questions/438785/xcode-error-when-launching-terminal
# - https://stackoverflow.com/questions/71320584/flutter-build-ios-got-error-requested-but-did-not-find-extension-point-with-ide
echo $xcodebuild_more_options
rm -fr "$__DIR__/libtdjson.xcframework"
xcodebuild -create-xcframework \
	${xcodebuild_more_options} \
	-output "$__DIR__/libtdjson.xcframework"
