#!/bin/bash

zip=$*
lang=$(echo $zip | sed "s/Firefox Aurora-\(.*\)\.zip/\1/")

(cd ../l10n/; ./get-and-reset-lang.sh $lang)

mkdir -p ../l10n/$lang
unzip -u -d ../l10n/$lang "$zip"

./recover-lang.sh $lang

rm $(find $lang -type f | egrep -v "\.po$")

pocount $lang | tail
