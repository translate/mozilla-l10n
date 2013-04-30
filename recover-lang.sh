#!/bin/bash

source ttk.inc.sh

langs=$*

for lang in $langs
do
	hg_lang=$(echo $lang | tr "_" "-")
	moz2po --progress=none --exclude=".hgtags" -t templates-en-US build/l10n/$hg_lang $lang
done
rm $(find $lang -type f | egrep -v "\.po$")

clean_po $langs
