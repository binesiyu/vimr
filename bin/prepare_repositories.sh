#!/bin/bash
set -Eeuo pipefail

echo "### Preparing repositories"
pushd "$( dirname "${BASH_SOURCE[0]}" )/.." > /dev/null

# delete all (local) tags
git tag | xargs git tag -d

pushd NvimView/neovim
    git tag | xargs git tag -d
popd

# delete all (local) branches
git for-each-ref --format="%(refname:strip=2)" refs/heads/ | xargs git branch -D
git checkout -b for_build

# update neovim
git submodule update --init --force

popd > /dev/null
echo "### Prepared repositories"
