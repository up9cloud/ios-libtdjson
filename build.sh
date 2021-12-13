#!/bin/bash -e

__DIR__="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# https://github.com/beeware/Python-Apple-support/releases/download/3.9-b3/Python-3.9-$platform-support.b3.tar.gz will Cause error: ...libOpenSSL.a(bss_mem.o), building for iOS, but linking in object file (.../libOpenSSL.a(bss_mem.o)) built for macOS, for architecture arm64
# https://github.com/krzyzanowskim/OpenSSL/archive/refs/tags/1.1.1100.tar.gz:
download_prebuilt_openssl() {
	local install_root_dir="$1"
	curl -SL https://github.com/krzyzanowskim/OpenSSL/archive/refs/tags/1.1.1100.tar.gz -o OpenSSL.tar.gz
	tar xzf OpenSSL.tar.gz \
		OpenSSL-1.1.1100/iphoneos \
		OpenSSL-1.1.1100/iphonesimulator \
		OpenSSL-1.1.1100/macosx

	mkdir -p $install_root_dir
	# standardize name
	mv OpenSSL-1.1.1100 $install_root_dir/openssl
	mv $install_root_dir/openssl/iphoneos $install_root_dir/openssl/iOS
	mv $install_root_dir/openssl/iphonesimulator $install_root_dir/openssl/iOS-simulator
	mv $install_root_dir/openssl/macosx $install_root_dir/openssl/macOS
	rm OpenSSL.tar.gz
}

BUILD_ROOT_DIR="$__DIR__/build"
INSTALL_ROOT_DIR="$__DIR__/install"
LIBS_DIR="$__DIR__/libs"
DYLIBS_DIR="$__DIR__/dylibs"
TD_DIR="$__DIR__/td"

# cleanup all
# rm -fr $BUILD_ROOT_DIR
# rm -fr $INSTALL_ROOT_DIR
# rm -fr $LIBS_DIR
# rm -fr $DYLIBS_DIR
# rm -fr $TD_DIR

# prepare
brew install gperf cmake
if [ ! -d "$TD_DIR" ]; then
	cd $__DIR__
	git clone https://github.com/tdlib/td.git
	cd td
	# https://github.com/tdlib/td/blame/master/CMakeLists.txt
	# git checkout tags/v1.7.9
	git checkout 7d41d9eaa58a6e0927806283252dc9e74eda5512
	cd ..
fi
if [ ! -d "$INSTALL_ROOT_DIR/openssl" ]; then
	download_prebuilt_openssl $INSTALL_ROOT_DIR
fi

# build, https://github.com/tdlib/td/tree/master/example/ios
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
		rm -rf $build_dir $install_dir
		mkdir -p $build_dir $install_dir
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

		mkdir -p $DYLIBS_DIR/$platform
		cp $install_dir/lib/libtdjson.dylib $DYLIBS_DIR/$platform/libtdjson.dylib
		install_name_tool -id @rpath/libtdjson.dylib $DYLIBS_DIR/$platform/libtdjson.dylib

		mkdir -p $LIBS_DIR/$platform/lib
		cp $install_dir/lib/*.a $LIBS_DIR/$platform/lib/
		cp -r $install_dir/include $LIBS_DIR/$platform/
	else
		more_options=""
		if [[ $platform = "watchOS" ]]; then
			more_options="$more_options -DTD_EXPERIMENTAL_WATCH_OS=ON"
		fi
		simulators="0 1"
		for simulator in $simulators; do
			openssl_install_path="$INSTALL_ROOT_DIR/openssl/${platform}"
			build_dir="$BUILD_ROOT_DIR/${platform}"
			install_dir="$INSTALL_ROOT_DIR/tdjson/${platform}"
			if [[ $simulator = "1" ]]; then
				openssl_install_path="${openssl_install_path}-simulator"
				build_dir="${build_dir}-simulator"
				install_dir="${install_dir}-simulator"
				ios_platform="SIMULATOR"
				# 64 bit only, to reduce lib size, see https://github.com/tdlib/td/blob/master/CMake/iOS.cmake
				# Because we're using lipo to combind simulator and real device libs, we can only choose one arm64 for that lib.
				# Obeviously, We should choose it for real device.
				if [[ $platform = "iOS" ]]; then
					more_options="$more_options -DIOS_ARCH=x86_64"
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

			rm -rf $build_dir $install_dir
			mkdir -p $build_dir $install_dir
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
		done

		# dynamic lib
		lib="$INSTALL_ROOT_DIR/tdjson/${platform}/lib/libtdjson.dylib"
		lib_simulator="$INSTALL_ROOT_DIR/tdjson/${platform}-simulator/lib/libtdjson.dylib"
		mkdir -p $DYLIBS_DIR/$platform
		lipo -create $lib $lib_simulator -o $DYLIBS_DIR/$platform/libtdjson.dylib
		install_name_tool -id @rpath/libtdjson.dylib $DYLIBS_DIR/$platform/libtdjson.dylib

		# static lib
		mkdir -p $LIBS_DIR/$platform/lib
		for file in $INSTALL_ROOT_DIR/tdjson/${platform}/lib/*.a; do
			f=$(basename $file)
			lib="$INSTALL_ROOT_DIR/tdjson/${platform}/lib/$f"
			lib_simulator="$INSTALL_ROOT_DIR/tdjson/${platform}-simulator/lib/$f"
			lipo -create $lib $lib_simulator -o $LIBS_DIR/$platform/lib/$f
		done
		rm -fr $LIBS_DIR/$platform/include
		cp -r $install_dir/include $LIBS_DIR/$platform/
	fi
done
