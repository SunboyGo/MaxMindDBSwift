#!/bin/bash

set -e

# 设置环境变量
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="${SCRIPT_DIR}"
BUILD_ROOT="${PROJECT_ROOT}/build"
INSTALL_ROOT="${PROJECT_ROOT}/install"
OUTPUT_DIR="${PROJECT_ROOT}/PackageOutput"
PKG_NAME="MaxMindDBSwift"
XCFRAMEWORK_NAME="${PKG_NAME}.xcframework"

# 清理旧的构建文件
rm -rf "${BUILD_ROOT}" "${INSTALL_ROOT}" "${OUTPUT_DIR}"

# 创建必要的目录
mkdir -p "${BUILD_ROOT}" \
         "${INSTALL_ROOT}/macos/lib" \
         "${INSTALL_ROOT}/macos/include" \
         "${INSTALL_ROOT}/ios/lib" \
         "${INSTALL_ROOT}/ios/include" \
         "${INSTALL_ROOT}/ios_simulator/lib" \
         "${INSTALL_ROOT}/ios_simulator/include" \
         "${OUTPUT_DIR}"

echo "开始构建..."

build_for_platform() {
    local platform=$1
    local install_path=$2
    local extra_flags=$3
    local host=$4
    
    echo "构建 ${platform} 版本..."
    # 清理并重新克隆源码
    cd "${PROJECT_ROOT}"
    rm -rf libmaxminddb
    git clone https://github.com/maxmind/libmaxminddb.git
    cd libmaxminddb
    git checkout "$VERSION"
    
    ./bootstrap
    if [ -n "$extra_flags" ]; then
        eval "$extra_flags"
    fi
    
    local configure_args="--prefix=${install_path} --disable-tests"
    if [ -n "$host" ]; then
        configure_args="$configure_args --host=$host"
    fi
    
    ./configure $configure_args
    make
    make install
}

# 构建 macOS 版本
build_for_platform "macOS" "${INSTALL_ROOT}/macos" \
    'export CC="$(xcrun -find -sdk macosx clang)" && export CFLAGS="-arch arm64 -mmacosx-version-min=10.15 -isysroot $(xcrun -sdk macosx --show-sdk-path)"' \
    "arm-apple-darwin"

# 构建 iOS 版本
build_for_platform "iOS" "${INSTALL_ROOT}/ios" \
    'export CC="$(xcrun -find -sdk iphoneos clang)" && export CFLAGS="-arch arm64 -mios-version-min=12.0 -isysroot $(xcrun -sdk iphoneos --show-sdk-path)"' \
    "arm-apple-darwin"

# 构建 iOS Simulator 版本
build_for_platform "iOS Simulator" "${INSTALL_ROOT}/ios_simulator" \
    'export CC="$(xcrun -find -sdk iphonesimulator clang)" && export CFLAGS="-arch x86_64 -mios-version-min=12.0 -isysroot $(xcrun -sdk iphonesimulator --show-sdk-path)"' \
    "x86_64-apple-darwin"

cd "${PROJECT_ROOT}"

echo "生成 XCFramework..."
xcodebuild -create-xcframework \
    -library "${INSTALL_ROOT}/macos/lib/libmaxminddb.a" -headers "${INSTALL_ROOT}/macos/include" \
    -library "${INSTALL_ROOT}/ios/lib/libmaxminddb.a" -headers "${INSTALL_ROOT}/ios/include" \
    -library "${INSTALL_ROOT}/ios_simulator/lib/libmaxminddb.a" -headers "${INSTALL_ROOT}/ios_simulator/include" \
    -output "${OUTPUT_DIR}/${XCFRAMEWORK_NAME}"

echo "准备 SwiftPM 包结构..."
PKG_ROOT="${OUTPUT_DIR}/${PKG_NAME}"
mkdir -p "${PKG_ROOT}/Sources/${PKG_NAME}" \
         "${PKG_ROOT}/Sources/CLibMaxMindDB" \
         "${PKG_ROOT}/XCFrameworks"

echo "生成 Package.swift..."
cat > "${PKG_ROOT}/Package.swift" <<EOF
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MaxMindDBSwift",
    platforms: [.iOS(.v12), .macOS(.v10_15)],
    products: [
        .library(
            name: "MaxMindDB",
            targets: ["MaxMindDB"]
        )
    ],
    targets: [
        .target(
            name: "MaxMindDB",
            dependencies: ["CLibMaxMindDB"],
            path: "Sources/MaxMindDBSwift"
        ),
        .binaryTarget(
            name: "CLibMaxMindDB",
            path: "XCFrameworks/MaxMindDBSwift.xcframework"
        )
    ]
)
EOF

echo "生成 module.modulemap..."
cat > "${PKG_ROOT}/Sources/CLibMaxMindDB/module.modulemap" <<EOF
module CLibMaxMindDB {
    umbrella header "maxminddb.h"
    link "maxminddb"
    export *
}
EOF

echo "复制文件..."
mv "${OUTPUT_DIR}/${XCFRAMEWORK_NAME}" "${PKG_ROOT}/XCFrameworks/"
cp "${INSTALL_ROOT}/macos/include/maxminddb.h" "${PKG_ROOT}/Sources/CLibMaxMindDB/"

# 复制 GeoIP2.swift
echo "复制 GeoIP2.swift..."
cp "${PROJECT_ROOT}/Sources/MaxMindDBSwift/GeoIP2.swift" "${PKG_ROOT}/Sources/${PKG_NAME}/"

echo "构建完成"
