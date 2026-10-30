#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[[ "$(uname -s)" == "Darwin" ]] || { echo 'Requires macOS and Apple Xcode toolchain' >&2; exit 1; }
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos clang \
  -arch arm64 -isysroot "$SDK" -miphoneos-version-min=13.0 \
  -dynamiclib -O2 -fPIC \
  -Wl,-install_name,@executable_path/Frameworks/ZeroV26Min.dylib \
  -o ZeroV26Min.dylib zero_v28_probe.c

codesign --force --sign - --timestamp=none ZeroV26Min.dylib
codesign --verify --strict --verbose=2 ZeroV26Min.dylib
xcrun lipo -archs ZeroV26Min.dylib | grep -qw arm64
xcrun otool -hv ZeroV26Min.dylib | grep -q MH_DYLIB
xcrun otool -l ZeroV26Min.dylib | grep -q LC_CODE_SIGNATURE
xcrun otool -l ZeroV26Min.dylib | grep -q LC_BUILD_VERSION
xcrun otool -D ZeroV26Min.dylib | grep -Fq '@executable_path/Frameworks/ZeroV26Min.dylib'
if xcrun otool -l ZeroV26Min.dylib | grep -q '__mod_init_func'; then
  echo 'Unexpected initializer section; aborting' >&2
  exit 2
fi
{
  echo 'platform: iOS'
  echo 'architecture: arm64'
  echo 'file_type: MH_DYLIB'
  echo 'probe_behavior: exports only a constant-returning function; no initializer'
  echo 'signature: ad-hoc (not an iPhone installation signature)'
  echo "sha256: $(shasum -a 256 ZeroV26Min.dylib | cut -d' ' -f1)"
  echo 'test_status: binary-format verified on macOS; NOT tested on iPhone'
} > probe_manifest.txt
cat probe_manifest.txt
