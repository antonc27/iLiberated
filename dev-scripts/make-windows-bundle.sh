#!/bin/sh
set -e

# Bundles the iLiberated executable with the basic set of files needed for
# iLiberated to run (the same ones found in the macOS .app bundle or Android APK).
# This does not prepare a full release.

if [[ $# == 1 ]]; then
    PATH_TO_BINARY="$1"
    shift

    rm -rf iLiberated_windows_bundle
    mkdir iLiberated_windows_bundle
    cp "$PATH_TO_BINARY" iLiberated_windows_bundle/iLiberated.exe
    cp -r ../touchHLE_dylibs iLiberated_windows_bundle/
    cp -r ../touchHLE_fonts iLiberated_windows_bundle/
    cp -r ../touchHLE_default_options.txt iLiberated_windows_bundle/
else
    echo "Incorrect usage."
    exit 1
fi
