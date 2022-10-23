#!/bin/bash -e

# See https://github.com/tdlib/td/blob/master/example/ios/build.sh

__DIR__="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# https://github.com/beeware/Python-Apple-support/releases/download/3.9-b3/Python-3.9-$platform-support.b3.tar.gz will Cause error: ...libOpenSSL.a(bss_mem.o), building for iOS, but linking in object file (.../libOpenSSL.a(bss_mem.o)) built for macOS, for architecture arm64
download_prebuilt_openssl() {
	local install_root_dir="$1"
	local v_tag=1.1.1700
	local f_name=OpenSSL.tar.gz
	curl -SL https://github.com/krzyzanowskim/OpenSSL/archive/refs/tags/${v_tag}.tar.gz -o $f_name
	tar xzf $f_name
	# The output folder name should be OpenSSL-${v_tag}
	mkdir -p $install_root_dir
	mv OpenSSL-${v_tag} $install_root_dir/openssl
	rm $f_name

	# standardize the folder name
	mv $install_root_dir/openssl/macosx $install_root_dir/openssl/macOS
	mv $install_root_dir/openssl/iphoneos $install_root_dir/openssl/iOS
	mv $install_root_dir/openssl/iphonesimulator $install_root_dir/openssl/iOS-simulator
}

BUILD_ROOT_DIR="$__DIR__/build"
INSTALL_ROOT_DIR="$__DIR__/install"
TD_DIR="$__DIR__/td"

# cleanup all
# rm -fr $BUILD_ROOT_DIR
# rm -fr $INSTALL_ROOT_DIR
# rm -fr $TD_DIR

# prepare
brew install gperf cmake coreutils
brew ls
if [ ! -d "$TD_DIR" ]; then
	cd $__DIR__
	git clone https://github.com/tdlib/td.git
	cd td
	# How to get the hash if there is no version tag:
	# - Goto https://github.com/tdlib/td/blame/master/CMakeLists.txt
	# - Check the line of `project(TDLib VERSION...
	# - Click left commit link
	# - Copy and paste the commit hash, e.q. git checkout <hash>
	# git checkout tags/v1.8.7
	git checkout a7a17b34b3c8fd3f7f6295f152746beb68f34d83
	cd ..
fi
if [ ! -d "$INSTALL_ROOT_DIR/openssl" ]; then
	download_prebuilt_openssl $INSTALL_ROOT_DIR
fi

# build, see https://github.com/tdlib/td/tree/master/example/ios
if [ -z "$1" ]; then
	# platforms="macOS iOS watchOS tvOS"
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
for platform in $platforms; do
	if [[ $platform = "macOS" ]]; then
		openssl_install_path="$INSTALL_ROOT_DIR/openssl/${platform}"
		openssl_crypto_library="${openssl_install_path}/lib/libcrypto.a"
		openssl_ssl_library="${openssl_install_path}/lib/libssl.a"

		build_dir="$BUILD_ROOT_DIR/${platform}"
		install_dir="$INSTALL_ROOT_DIR/tdjson/${platform}"
		install_dylib_dir="$INSTALL_ROOT_DIR/libtdjson/$platform"

		rm -rf $build_dir $install_dir $install_dylib_dir
		mkdir -p $build_dir $install_dir $install_dylib_dir

		cd $build_dir
		cmake $TD_DIR \
			-DCMAKE_INSTALL_PREFIX=$install_dir \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_OSX_ARCHITECTURES='x86_64;arm64' \
			-DOPENSSL_FOUND=1 \
			-DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library} \
			-DOPENSSL_SSL_LIBRARY=${openssl_ssl_library} \
			-DOPENSSL_INCLUDE_DIR=${openssl_install_path}/include \
			-DOPENSSL_LIBRARIES="${openssl_crypto_library};${openssl_ssl_library}" || exit 1
		cmake --build . --target tdjson || exit 1
		cmake --build . --target tdjson_static || exit 1
		cmake --install . || exit 1

		cp $install_dir/lib/libtdjson.dylib "$install_dylib_dir/libtdjson.dylib"
		install_name_tool -id @rpath/libtdjson.dylib "$install_dylib_dir/libtdjson.dylib"
	else
		more_options=""
		simulators="0 1"
		for simulator in $simulators; do
			openssl_install_path="$INSTALL_ROOT_DIR/openssl/${platform}"
			build_dir="$BUILD_ROOT_DIR/${platform}"
			install_dir="$INSTALL_ROOT_DIR/tdjson/${platform}"
			install_dylib_dir="$INSTALL_ROOT_DIR/libtdjson/$platform"
			if [[ $simulator = "1" ]]; then
				openssl_install_path="${openssl_install_path}-simulator"
				build_dir="${build_dir}-simulator"
				install_dir="${install_dir}-simulator"
				install_dylib_dir="${install_dylib_dir}-simulator"
				ios_platform="SIMULATOR"
				# - 64 bit only, to reduce lib size, see https://github.com/tdlib/td/blob/master/CMake/iOS.cmake
				if [[ $platform = "iOS" ]]; then
					more_options="$more_options -DIOS_ARCH=x86_64;arm64"
				fi
			else
				ios_platform="OS"
				if [[ $platform = "iOS" ]]; then
					more_options="$more_options -DIOS_ARCH=arm64"
				fi
			fi
			if [[ $platform = "watchOS" ]]; then
				ios_platform="WATCH${ios_platform}"
			elif [[ $platform = "tvOS" ]]; then
				ios_platform="TV${ios_platform}"
			fi
			openssl_crypto_library="${openssl_install_path}/lib/libcrypto.a"
			openssl_ssl_library="${openssl_install_path}/lib/libssl.a"

			rm -rf $build_dir $install_dir $install_dylib_dir
			mkdir -p $build_dir $install_dir $install_dylib_dir

			cd $build_dir
			cmake $TD_DIR $more_options \
				-DIOS_PLATFORM=${ios_platform} \
				-DCMAKE_BUILD_TYPE=MinSizeRel \
				-DCMAKE_INSTALL_PREFIX=$install_dir \
				-DCMAKE_TOOLCHAIN_FILE=${TD_DIR}/CMake/iOS.cmake \
				-DOPENSSL_FOUND=1 \
				-DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library} \
				-DOPENSSL_SSL_LIBRARY=${openssl_ssl_library} \
				-DOPENSSL_INCLUDE_DIR=${openssl_install_path}/include \
				-DOPENSSL_LIBRARIES="${openssl_crypto_library};${openssl_ssl_library}" || exit 1
			cmake --build . --target tdjson || exit 1
			cmake --build . --target tdjson_static || exit 1
			cmake --install . || exit 1

			cp $install_dir/lib/libtdjson.dylib "$install_dylib_dir/libtdjson.dylib"
			install_name_tool -id @rpath/libtdjson.dylib "$install_dylib_dir/libtdjson.dylib"
		done
	fi
done

# What if met the error: Requested but did not find extension point with identifier Xcode.IDEKit.ExtensionSentinelHostApplications for extension Xcode.DebuggerFoundation.AppExtensionHosts.watchOS of plug-in com.apple.dt.IDEWatchSupportCore...
# see:
# - https://apple.stackexchange.com/questions/438785/xcode-error-when-launching-terminal
# - https://stackoverflow.com/questions/71320584/flutter-build-ios-got-error-requested-but-did-not-find-extension-point-with-ide
xcodebuild_more_options=""
for dylib in $INSTALL_ROOT_DIR/libtdjson/*/libtdjson.dylib; do
	abs_path="$(grealpath "${dylib}")"
	xcodebuild_more_options="$xcodebuild_more_options -library $abs_path"
done

xcodebuild -create-xcframework \
	${xcodebuild_more_options} \
	-output "$__DIR__/libtdjson.xcframework"
