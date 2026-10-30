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

# Collect outputs before matching: avoid pipefail + grep -q SIGPIPE from long otool output.
archs="$(xcrun lipo -archs ZeroV26Min.dylib)"
header="$(xcrun otool -hv ZeroV26Min.dylib)"
load_cmds="$(xcrun otool -l ZeroV26Min.dylib)"
install_name="$(xcrun otool -D ZeroV26Min.dylib)"
printf 'Architecture: %s\nMach-O header:\n%s\n' "$archs" "$header"
printf 'Install name:\n%s\n' "$install_name"
check() { local name="$1"; shift; if "$@"; then echo "PASS $name"; else echo "FAIL $name" >&2; exit 3; fi; }
check arm64 grep -qw arm64 <<< "$archs"
# Apple's otool -hv writes "DYLIB", not necessarily "MH_DYLIB".
check dylib_filetype grep -Eq '(^|[[:space:]])(MH_)?DYLIB([[:space:]]|$)' <<< "$header"
check code_signature grep -q 'LC_CODE_SIGNATURE' <<< "$load_cmds"
check apple_platform grep -Eq 'LC_BUILD_VERSION|LC_VERSION_MIN_IPHONEOS' <<< "$load_cmds"
check install_name grep -Fq '@executable_path/Frameworks/ZeroV26Min.dylib' <<< "$install_name"
if grep -q '__mod_init_func' <<< "$load_cmds"; then
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
