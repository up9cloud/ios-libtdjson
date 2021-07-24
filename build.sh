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
	git checkout tags/v1.7.0
	cd ..

	# 64 bit only, to reduce lib size
	sed -i '' "s/armv7;armv7s;arm64/arm64/" $TD_DIR/CMake/iOS.cmake
	sed -i '' "s/i386;x86_64/x86_64/" $TD_DIR/CMake/iOS.cmake
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
		options="$options -DOPENSSL_FOUND=1"
		options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
		options="$options -DOPENSSL_SSL_LIBRARY=${openssl_ssl_library}"
		options="$options -DOPENSSL_INCLUDE_DIR=${openssl_install_path}/include"
		options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library};${openssl_ssl_library}"
		options="$options -DCMAKE_BUILD_TYPE=Release"

		build_dir="$BUILD_ROOT_DIR/${platform}"
		install_dir="$INSTALL_ROOT_DIR/tdjson/${platform}"
		rm -rf $build_dir $install_dir
		mkdir -p $build_dir $install_dir
		cd $build_dir
		cmake $TD_DIR $options -DCMAKE_INSTALL_PREFIX=$install_dir || exit 1
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
		options="$options -DCMAKE_BUILD_TYPE=MinSizeRel"
		options="$options -DCMAKE_TOOLCHAIN_FILE=${TD_DIR}/CMake/iOS.cmake"
		if [[ $platform = "watchOS" ]]; then
			options="$options -DTD_EXPERIMENTAL_WATCH_OS=ON"
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
			else
				ios_platform="OS"
			fi
			if [[ $platform = "watchOS" ]]; then
				ios_platform="WATCH${ios_platform}"
			elif [[ $platform = "tvOS" ]]; then
				ios_platform="TV${ios_platform}"
			fi
			openssl_crypto_library="${openssl_install_path}/lib/libcrypto.a"
			openssl_ssl_library="${openssl_install_path}/lib/libssl.a"
			options="$options -DOPENSSL_FOUND=1"
			options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
			options="$options -DOPENSSL_SSL_LIBRARY=${openssl_ssl_library}"
			options="$options -DOPENSSL_INCLUDE_DIR=${openssl_install_path}/include"
			options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library};${openssl_ssl_library}"

			rm -rf $build_dir $install_dir
			mkdir -p $build_dir $install_dir
			cd $build_dir
			cmake $TD_DIR $options -DIOS_PLATFORM=${ios_platform} -DCMAKE_INSTALL_PREFIX=$install_dir || exit 1
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
		for file in $INSTALL_ROOT_DIR/tdjson/${platform}/lib/*.a; do
			f=$(basename $file)
			lib="$INSTALL_ROOT_DIR/tdjson/${platform}/lib/$f"
			lib_simulator="$INSTALL_ROOT_DIR/tdjson/${platform}-simulator/lib/$f"
			mkdir -p $LIBS_DIR/$platform/lib
			lipo -create $lib $lib_simulator -o $LIBS_DIR/$platform/lib/$f
		done
		rm -fr $LIBS_DIR/$platform/include
		cp -r $install_dir/include $LIBS_DIR/$platform/
	fi
done
