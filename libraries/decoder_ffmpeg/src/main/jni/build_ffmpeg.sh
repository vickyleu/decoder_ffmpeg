#!/bin/bash
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -eu


# 用户输入 NDK 路径
read -p "请输入 NDK 路径 [默认: /path/to/ndk]: " NDK_PATH
NDK_PATH=${NDK_PATH:-/path/to/ndk}
echo "NDK 路径是 ${NDK_PATH}"

# 用户输入 Host 平台
read -p "请输入 Host 平台 [默认: darwin-x86_64]: " HOST_PLATFORM
HOST_PLATFORM=${HOST_PLATFORM:-darwin-x86_64}
echo "Host 平台是 ${HOST_PLATFORM}"

# 用户输入 ANDROID_ABI
read -p "请输入 ANDROID_ABI [默认: 21]: " ANDROID_ABI
ANDROID_ABI=${ANDROID_ABI:-21}
echo "ANDROID_ABI 是 ${ANDROID_ABI}"

# 初始化空数组
USER_INPUT_DECODERS=()
# 用户输入启用的解码器列表（以空格分隔）
read -p "请输入启用的解码器（以空格分隔）[默认: vorbis opus flac alac pcm_mulaw pcm_alaw mp3 amrnb amrwb aac ac3 eac3 dca mlp truehd]: " -a ENABLED_DECODERS
# shellcheck disable=SC2178
# shellcheck disable=SC2140
if [ ${#USER_INPUT_DECODERS[@]} -eq 0 ]; then
    ENABLED_DECODERS=("vorbis" "opus" "flac" "alac" "pcm_mulaw" "pcm_alaw" "mp3" "amrnb" "amrwb" "aac" "ac3" "eac3" "dca" "mlp" "truehd")
else
    ENABLED_DECODERS=("${USER_INPUT_DECODERS[@]}")
fi

echo "启用的解码器是 ${ENABLED_DECODERS[@]}"

# 克隆 ffmpeg 仓库
git clone git://source.ffmpeg.org/ffmpeg || echo "ffmpeg 已存在 !" && \
cd ffmpeg && \
git checkout release/6.0 && \
echo "ffmpeg 已切换到 release/6.0 分支 !" && \
FFMPEG_MODULE_PATH="$(pwd)"
echo "FFMPEG_MODULE_PATH 是 ${FFMPEG_MODULE_PATH}"

# 使用 CPU 核心数进行编译
JOBS="$(nproc 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 4)"
echo "使用 $JOBS 个工作线程进行 make"



TOOLCHAIN_PREFIX="${NDK_PATH}/toolchains/llvm/prebuilt/${HOST_PLATFORM}/bin"
if [[ ! -d "${TOOLCHAIN_PREFIX}" ]]; then
    echo "请设置正确的 NDK_PATH，${NDK_PATH} 不正确"
    exit 1
fi



# 检查 ARMV7 编译器是否存在
ARMV7_CLANG="${TOOLCHAIN_PREFIX}/armv7a-linux-androideabi${ANDROID_ABI}-clang"
if [[ ! -e "$ARMV7_CLANG" ]]; then
    echo "AVMv7 Clang 编译器路径 $ARMV7_CLANG 不存在"
    echo "可能是你的 NDK 版本不支持 ANDROID_ABI $ANDROID_ABI"
    echo "请使用旧版本的 NDK 或提高 ANDROID_ABI （注意 ANDROID_ABI 不能大于你的应用的 minSdk）"
    exit 1
fi

# 检查 64 位 ANDROID_ABI
ANDROID_ABI_64BIT="$ANDROID_ABI"
if [[ "$ANDROID_ABI_64BIT" -lt 21 ]]; then
    echo "使用 ANDROID_ABI 21 进行 64 位架构编译"
    ANDROID_ABI_64BIT=21
fi

COMMON_OPTIONS="
    --target-os=android
    --enable-static
    --disable-shared
    --disable-doc
    --disable-programs
    --disable-everything
    --disable-avdevice
    --disable-avformat
    --disable-swscale
    --disable-postproc
    --disable-avfilter
    --disable-symver
    --enable-swresample
    --extra-ldexeflags=-pie
    --disable-v4l2-m2m
    --disable-vulkan
    "
# 添加启用的解码器选项
for decoder in "${ENABLED_DECODERS[@]}"; do
    COMMON_OPTIONS="${COMMON_OPTIONS} --enable-decoder=${decoder}"
done

cd "${FFMPEG_MODULE_PATH}"
./configure \
    --libdir=android-libs/armeabi-v7a \
    --arch=arm \
    --cpu=armv7-a \
    --cross-prefix="${TOOLCHAIN_PREFIX}/armv7a-linux-androideabi${ANDROID_ABI}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    --extra-cflags="-march=armv7-a -mfloat-abi=softfp" \
    --extra-ldflags="-Wl,--fix-cortex-a8" \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
./configure \
    --libdir=android-libs/arm64-v8a \
    --arch=aarch64 \
    --cpu=armv8-a \
    --cross-prefix="${TOOLCHAIN_PREFIX}/aarch64-linux-android${ANDROID_ABI_64BIT}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
./configure \
    --libdir=android-libs/x86 \
    --arch=x86 \
    --cpu=i686 \
    --cross-prefix="${TOOLCHAIN_PREFIX}/i686-linux-android${ANDROID_ABI}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    --disable-asm \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
./configure \
    --libdir=android-libs/x86_64 \
    --arch=x86_64 \
    --cpu=x86-64 \
    --cross-prefix="${TOOLCHAIN_PREFIX}/x86_64-linux-android${ANDROID_ABI_64BIT}-" \
    --nm="${TOOLCHAIN_PREFIX}/llvm-nm" \
    --ar="${TOOLCHAIN_PREFIX}/llvm-ar" \
    --ranlib="${TOOLCHAIN_PREFIX}/llvm-ranlib" \
    --strip="${TOOLCHAIN_PREFIX}/llvm-strip" \
    --disable-asm \
    ${COMMON_OPTIONS}
make -j$JOBS
make install-libs
make clean
