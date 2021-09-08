#!/usr/bin/env bash

set -uex

ROOT=$(cd "$(dirname "$0")" && pwd)
REDIS_VERSION=$1
: "${RUNNER_TEMP:=$ROOT/.work}"
: "${RUNNER_TOOL_CACHE:=$RUNNER_TEMP/dist}"
PREFIX=$RUNNER_TOOL_CACHE/redis/$REDIS_VERSION/x64

# detect the number of CPU Core
JOBS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu_max 2>/dev/null)

# bundle OpenSSL for better reproducibility.
OPENSSL_VERSION=1_1_1l
mkdir -p "$RUNNER_TEMP"
cd "$RUNNER_TEMP"

echo "::group::download OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    curl --retry 3 -sSL "https://github.com/openssl/openssl/archive/OpenSSL_$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
)
echo "::endgroup::"

echo "::group::extract OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    tar zxvf openssl.tar.gz
)
echo "::endgroup::"

echo "::group::build OpenSSL"
(
    set -eux
    TARGET=""
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin) TARGET="darwin64-x86_64-cc" ;;
        linux) TARGET="linux-x86_64" ;;
    esac
    cd "$RUNNER_TEMP/openssl-OpenSSL_$OPENSSL_VERSION"
    ./Configure --prefix="$PREFIX" "$TARGET"
    make "-j$JOBS"
    make install_sw install_ssldirs
)
echo "::endgroup::"

# download
echo "::group::download redis source"
(
    mkdir -p "$RUNNER_TEMP"
    curl -sSL "https://github.com/antirez/redis/archive/$REDIS_VERSION.tar.gz" -o "$RUNNER_TEMP/redis.tar.gz"
)
echo "::endgroup::"

# build
echo "::group::build redis"
(
    cd "$RUNNER_TEMP"
    tar xzf redis.tar.gz
    cd "redis-$REDIS_VERSION"
    perl -pi -e "s(OPENSSL_PREFIX=.*$)(OPENSSL_PREFIX=$PREFIX)" src/Makefile
    perl -pi -e "s(OPENSSL_CFLAGS=.*$)(OPENSSL_CFLAGS=-I$PREFIX/include)" src/Makefile
    perl -pi -e "s(OPENSSL_LDFLAGS=.*$)(OPENSSL_LDFLAGS=-L$PREFIX/lib)" src/Makefile
    make "-j$JOBS" PREFIX="$PREFIX" BUILD_TLS=yes OPENSSL_PREFIX="$PREFIX"
)
echo "::endgroup::"

echo "::group::archive redis binary"
(
    cd "$RUNNER_TEMP/redis-$REDIS_VERSION"
    mkdir -p "$PREFIX"
    make install PREFIX="$PREFIX"

    # remove dev packages
    rm -rf "$PREFIX/include"
    rm -rf "$PREFIX/lib/pkgconfig"

    cd "$PREFIX"
    tar Jcvf "$RUNNER_TEMP/redis-bin.tar.xz" .
)
echo "::endgroup::"
