#!/bin/bash

source ttk.inc.sh

langs=$*

for lang in $langs
do
	mozlang=$(get_language_upstream $lang)
	polang=$(get_language_pootle $lang)
	moz2po --progress=$progress --errorlevel=$errorlevel --exclude=".hgtags" -t templates-en-US build/l10n/$mozlang $polang
done

# Remove any non-PO files
rm $(find $polang -type f | egrep -v "\.po$")

clean_po $langs
