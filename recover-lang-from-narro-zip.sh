#!/bin/bash

zip=$*
lang=$(echo $zip | sed "s/.*Firefox Aurora-\(.*\)\.zip/\1/")

# Make sure we have the Mercurial repo updated
(cd ../l10n/; ./get-and-reset-lang.sh $lang)

# Prepare the unzipped Narro files
mkdir -p ../l10n/$lang
unzip -u -d ../l10n/$lang "$zip"

# Do a normal recovery
./recover-lang.sh $lang

# Remove any non-PO files
rm $(find $lang -type f | egrep -v "\.po$")

# TODO update to latest templates

pocount $lang | tail
