#!/bin/bash

zip=$*
lang=$(echo $zip | sed "s/.*Firefox Aurora-\(.*\)\.zip/\1/")

# Make sure we have the Mercurial repo updated
(cd build/l10n/; ./get-and-reset-lang.sh $lang)

# Prepare the unzipped Narro files
mkdir -p build/l10n/$lang
unzip -u -d build/l10n/$lang "$zip"

# Do a normal recovery
./recover-lang.sh $lang

pocount $lang | tail
