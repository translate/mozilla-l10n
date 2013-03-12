#!/bin/bash

lang=$1
shift
files=$*

source build_common.inc.sh

cd ..
for file in $files
do
	moz2po -t l10n/en-US/$file l10n/$lang/$file po/$lang/${file}.po
done
cd po
clean_po $lang
