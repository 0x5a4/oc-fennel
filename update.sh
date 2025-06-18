#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

echo building fennel
nix build

echo removing old version
rm -r fennel

echo copy new version
cp -r --no-preserve=all result/ fennel
