#!/bin/bash
set -Eeuo pipefail

echo "### Building VimR target"
pushd "$( dirname "${BASH_SOURCE[0]}" )/.." > /dev/null

readonly deployment_target_file="./resources/macos_deployment_target.txt"
readonly deployment_target=$(cat ${deployment_target_file})
readonly code_sign=${code_sign:?"true or false"}
readonly use_carthage_cache=${use_carthage_cache:?"true or false"}
readonly build_path="./build"

# Build NeoVim
# 0. Delete previously built things
# 1. Build normally to get the full runtime folder and copy it to the neovim's project root
# 2. Delete the build folder to re-configure
# 3. Build libnvim
pushd NvimView/neovim
    ln -f -s ../local.mk .

    rm -rf build
    make distclean

    echo "### Building nvim to get the complete runtime folder"
    rm -rf /tmp/nvim-runtime
    make \
        CFLAGS="-mmacosx-version-min=${deployment_target}" \
        MACOSX_DEPLOYMENT_TARGET=${deployment_target} \
        CMAKE_FLAGS="-DCUSTOM_UI=0 -DCMAKE_INSTALL_PREFIX=/tmp/nvim-runtime" \
        install

    rm -rf build
    make clean

    ../../bin/build_libnvim.sh

    echo "### Copying runtime"
    rm -rf runtime
    cp -r /tmp/nvim-runtime/share/nvim/runtime .
popd > /dev/null

echo "### Updating carthage"
if [[ ${use_carthage_cache} == true ]]; then
    carthage update --cache-builds --platform macos
else
    carthage update --platform macos
fi

echo "### Xcodebuilding"

rm -rf ${build_path}

if [[ ${code_sign} == true ]] ; then
    xcodebuild CODE_SIGN_IDENTITY="Developer ID Application: Tae Won Ha (H96Q2NKTQH)" -configuration Release -scheme VimR -workspace VimR.xcworkspace -derivedDataPath ${build_path} clean build
else
    xcodebuild -configuration Release -scheme VimR -workspace VimR.xcworkspace -derivedDataPath ${build_path} clean build
fi

popd > /dev/null
echo "### Built VimR target"
