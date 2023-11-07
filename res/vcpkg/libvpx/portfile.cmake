vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO webmproject/libvpx
    REF "v${VERSION}"
    SHA512 49706838563c92fab7334376848d0f374efcbc1729ef511e967c908fd2ecd40e8d197f1d85da6553b3a7026bdbc17e5a76595319858af26ce58cb9a4c3854897
    HEAD_REF master
    PATCHES
        0002-Fix-nasm-debug-format-flag.patch
        0003-add-uwp-v142-and-v143-support.patch
        0004-remove-library-suffixes.patch
        0005-fix-arm64-build.patch # Upstream commit: https://github.com/webmproject/libvpx/commit/858a8c611f4c965078485860a6820e2135e6611b
)

vcpkg_find_acquire_program(PERL)

get_filename_component(PERL_EXE_PATH ${PERL} DIRECTORY)

if(CMAKE_HOST_WIN32)
    vcpkg_acquire_msys(MSYS_ROOT PACKAGES make)
    set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
    set(ENV{PATH} "${MSYS_ROOT}/usr/bin;$ENV{PATH};${PERL_EXE_PATH}")
else()
    set(BASH /bin/bash)
    set(ENV{PATH} "${MSYS_ROOT}/usr/bin:$ENV{PATH}:${PERL_EXE_PATH}")
endif()

if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    vcpkg_find_acquire_program(NASM)
    get_filename_component(NASM_EXE_PATH ${NASM} DIRECTORY)
    vcpkg_add_to_path(${NASM_EXE_PATH})

    file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-tmp")

    if(VCPKG_CRT_LINKAGE STREQUAL static)
        set(LIBVPX_CRT_LINKAGE --enable-static-msvcrt)
        set(LIBVPX_CRT_SUFFIX mt)
    else()
        set(LIBVPX_CRT_SUFFIX md)
    endif()

    if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL WindowsStore AND (VCPKG_PLATFORM_TOOLSET STREQUAL v142 OR VCPKG_PLATFORM_TOOLSET STREQUAL v143))
        set(LIBVPX_TARGET_OS "uwp")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x86 OR VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
        set(LIBVPX_TARGET_OS "win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x64 OR VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
        set(LIBVPX_TARGET_OS "win64")
    endif()

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL x86)
        set(LIBVPX_TARGET_ARCH "x86-${LIBVPX_TARGET_OS}")
        set(LIBVPX_ARCH_DIR "Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x64)
        set(LIBVPX_TARGET_ARCH "x86_64-${LIBVPX_TARGET_OS}")
        set(LIBVPX_ARCH_DIR "x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
        set(LIBVPX_TARGET_ARCH "arm64-${LIBVPX_TARGET_OS}")
        set(LIBVPX_ARCH_DIR "ARM64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
        set(LIBVPX_TARGET_ARCH "armv7-${LIBVPX_TARGET_OS}")
        set(LIBVPX_ARCH_DIR "ARM")
    endif()

    if(VCPKG_PLATFORM_TOOLSET STREQUAL v143)
        set(LIBVPX_TARGET_VS "vs17")
    elseif(VCPKG_PLATFORM_TOOLSET STREQUAL v142)
        set(LIBVPX_TARGET_VS "vs16")
    else()
        set(LIBVPX_TARGET_VS "vs15")
    endif()

    set(OPTIONS "--disable-examples --disable-tools --disable-docs --enable-pic")

    if("realtime" IN_LIST FEATURES)
        set(OPTIONS "${OPTIONS} --enable-realtime-only")
    endif()

    if("highbitdepth" IN_LIST FEATURES)
        set(OPTIONS "${OPTIONS} --enable-vp9-highbitdepth")
    endif()

    message(STATUS "Generating makefile")
    file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-tmp")
    vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc
            "${SOURCE_PATH}/configure"
            --target=${LIBVPX_TARGET_ARCH}-${LIBVPX_TARGET_VS}
            ${LIBVPX_CRT_LINKAGE}
            ${OPTIONS}
            --as=nasm
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-tmp"
        LOGNAME configure-${TARGET_TRIPLET})

    message(STATUS "Generating MSBuild projects")
    vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc -c "make dist"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-tmp"
        LOGNAME generate-${TARGET_TRIPLET})

    vcpkg_msbuild_install(
        SOURCE_PATH "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-tmp"
        PROJECT_SUBPATH vpx.vcxproj
    )

    if (VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
        set(LIBVPX_INCLUDE_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vpx-vp8-vp9-nopost-nodocs-${LIBVPX_TARGET_ARCH}${LIBVPX_CRT_SUFFIX}-${LIBVPX_TARGET_VS}-v${VERSION}/include/vpx")
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
        set(LIBVPX_INCLUDE_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vpx-vp8-vp9-nopost-nomt-nodocs-${LIBVPX_TARGET_ARCH}${LIBVPX_CRT_SUFFIX}-${LIBVPX_TARGET_VS}-v${VERSION}/include/vpx")
    else()
        set(LIBVPX_INCLUDE_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/vpx-vp8-vp9-nodocs-${LIBVPX_TARGET_ARCH}${LIBVPX_CRT_SUFFIX}-${LIBVPX_TARGET_VS}-v${VERSION}/include/vpx")
    endif()
    file(
        INSTALL
            "${LIBVPX_INCLUDE_DIR}"
        DESTINATION
            "${CURRENT_PACKAGES_DIR}/include"
        RENAME
            "vpx")
    if (NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        set(LIBVPX_PREFIX "${CURRENT_INSTALLED_DIR}")
        configure_file("${CMAKE_CURRENT_LIST_DIR}/vpx.pc.in" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/vpx.pc" @ONLY)
    endif()

    if (NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        set(LIBVPX_PREFIX "${CURRENT_INSTALLED_DIR}/debug")
        configure_file("${CMAKE_CURRENT_LIST_DIR}/vpx.pc.in" "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/vpx.pc" @ONLY)
    endif()

else()
    vcpkg_find_acquire_program(YASM)
    get_filename_component(YASM_EXE_PATH ${YASM} DIRECTORY)
    vcpkg_add_to_path(${YASM_EXE_PATH})

    set(OPTIONS "--disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-pic")

    set(OPTIONS_DEBUG "--enable-debug-libs --enable-debug --prefix=${CURRENT_PACKAGES_DIR}/debug")
    set(OPTIONS_RELEASE "--prefix=${CURRENT_PACKAGES_DIR}")

    if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        set(OPTIONS "${OPTIONS} --disable-static --enable-shared")
    else()
        set(OPTIONS "${OPTIONS} --enable-static --disable-shared")
    endif()

    if("realtime" IN_LIST FEATURES)
        set(OPTIONS "${OPTIONS} --enable-realtime-only")
    endif()

    if("highbitdepth" IN_LIST FEATURES)
        set(OPTIONS "${OPTIONS} --enable-vp9-highbitdepth")
    endif()

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL x86)
        set(LIBVPX_TARGET_ARCH "x86")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x64)
        set(LIBVPX_TARGET_ARCH "x86_64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
        set(LIBVPX_TARGET_ARCH "armv7")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
        set(LIBVPX_TARGET_ARCH "arm64")
    else()
        message(FATAL_ERROR "libvpx does not support architecture ${VCPKG_TARGET_ARCHITECTURE}")
    endif()

    if(VCPKG_TARGET_IS_MINGW)
        if(LIBVPX_TARGET_ARCH STREQUAL "x86")
            set(LIBVPX_TARGET "x86-win32-gcc")
        else()
            set(LIBVPX_TARGET "x86_64-win64-gcc")
        endif()
    elseif(VCPKG_TARGET_IS_LINUX)
        set(LIBVPX_TARGET "${LIBVPX_TARGET_ARCH}-linux-gcc")
        include($ENV{VCPKG_ROOT}/buildtrees/detect_compiler/${VCPKG_TARGET_ARCHITECTURE}-linux-rel/CMakeFiles/${CMAKE_VERSION}/CMakeCCompiler.cmake)
        set(ENV{CROSS} "${CMAKE_LIBRARY_ARCHITECTURE}-")
    elseif(VCPKG_TARGET_IS_ANDROID)
        set(LIBVPX_TARGET "${LIBVPX_TARGET_ARCH}-android-gcc")
        set(ANDROID_API 21)
        # From ndk android.toolchsin.cmake
        if(CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)
          set(ANDROID_HOST_TAG linux-x86_64)
        elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Darwin)
          set(ANDROID_HOST_TAG darwin-x86_64)
        elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL Windows)
          set(ANDROID_HOST_TAG windows-x86_64)
        endif()
        set(ANDROID_TOOLCHAIN_ROOT
          "$ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${ANDROID_HOST_TAG}")
        # Settings
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL x86)
            set(ANDROID_TARGET_TRIPLET i686-linux-android)
            set(OPTIONS "${OPTIONS} --disable-sse4_1 --disable-avx --disable-avx2 --disable-avx512")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL x64)
            set(ANDROID_TARGET_TRIPLET x86_64-linux-android)
            set(OPTIONS "${OPTIONS} --disable-avx --disable-avx2 --disable-avx512")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
            set(ANDROID_TARGET_TRIPLET armv7a-linux-androideabi)
            set(OPTIONS "${OPTIONS} --enable-thumb --disable-neon")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
            set(ANDROID_TARGET_TRIPLET aarch64-linux-android)
            set(OPTIONS "${OPTIONS} --enable-thumb --disable-neon")
        endif()
        # Set environment variables for configure
        set(ENV{CC} "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TARGET_TRIPLET}${ANDROID_API}-clang")
        set(ENV{CXX} "${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TARGET_TRIPLET}${ANDROID_API}-clang++")
        set(ENV{AR} "${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ar")
        set(ENV{AS} "${CMAKE_C_COMPILER}")
        set(ENV{LD} "${ANDROID_TOOLCHAIN_ROOT}/bin/ld")
        set(ENV{RANLIB} "${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ranlib")
        set(ENV{STRIP} "${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-strip")
    elseif(VCPKG_TARGET_IS_OSX)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(LIBVPX_TARGET "arm64-darwin20-gcc")
            if(DEFINED VCPKG_OSX_DEPLOYMENT_TARGET)
                set(MAC_OSX_MIN_VERSION_CFLAGS --extra-cflags=-mmacosx-version-min=${VCPKG_OSX_DEPLOYMENT_TARGET} --extra-cxxflags=-mmacosx-version-min=${VCPKG_OSX_DEPLOYMENT_TARGET})
            endif()
        else()
            set(LIBVPX_TARGET "${LIBVPX_TARGET_ARCH}-darwin17-gcc") # enable latest CPU instructions for best performance and less CPU usage on MacOS
        endif()
    elseif(VCPKG_TARGET_IS_IOS)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL arm)
            set(LIBVPX_TARGET "armv7-darwin-gcc")
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
            set(LIBVPX_TARGET "arm64-darwin-gcc")
        else()
            message(FATAL_ERROR "libvpx does not support architecture ${VCPKG_TARGET_ARCHITECTURE} on iOS")
        endif()
    else()
        set(LIBVPX_TARGET "generic-gnu") # use default target
    endif()

    message(STATUS "Build info. Target: ${LIBVPX_TARGET}; Options: ${OPTIONS}")

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        message(STATUS "Configuring libvpx for Release")
        file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
        vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc
            "${SOURCE_PATH}/configure"
            --target=${LIBVPX_TARGET}
            ${OPTIONS}
            ${OPTIONS_RELEASE}
            ${MAC_OSX_MIN_VERSION_CFLAGS}
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        LOGNAME configure-${TARGET_TRIPLET}-rel)

        message(STATUS "Building libvpx for Release")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make -j"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            LOGNAME build-${TARGET_TRIPLET}-rel
        )

        message(STATUS "Installing libvpx for Release")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make install"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            LOGNAME install-${TARGET_TRIPLET}-rel
        )
    endif()

    # --- --- ---

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        message(STATUS "Configuring libvpx for Debug")
        file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
        vcpkg_execute_required_process(
        COMMAND
            ${BASH} --noprofile --norc
            "${SOURCE_PATH}/configure"
            --target=${LIBVPX_TARGET}
            ${OPTIONS}
            ${OPTIONS_DEBUG}
            ${MAC_OSX_MIN_VERSION_CFLAGS}
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
        LOGNAME configure-${TARGET_TRIPLET}-dbg)

        message(STATUS "Building libvpx for Debug")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make -j"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
            LOGNAME build-${TARGET_TRIPLET}-dbg
        )

        message(STATUS "Installing libvpx for Debug")
        vcpkg_execute_required_process(
            COMMAND
                ${BASH} --noprofile --norc -c "make install"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
            LOGNAME install-${TARGET_TRIPLET}-dbg
        )

        file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
        file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/lib/libvpx_g.a")
    endif()
endif()

vcpkg_fixup_pkgconfig()

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    set(LIBVPX_CONFIG_DEBUG ON)
else()
    set(LIBVPX_CONFIG_DEBUG OFF)
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/unofficial-libvpx-config.cmake.in" "${CURRENT_PACKAGES_DIR}/share/unofficial-libvpx/unofficial-libvpx-config.cmake" @ONLY)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")