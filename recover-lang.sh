#!/bin/bash

source build_common.inc.sh

langs=$*

export PYTHONPATH=../tools/translate:$PYTHONPATH
export PATH=../tools/translate/translate/convert:$PATH

for lang in $langs
do
	moz2po --progress=none --exclude=".hgtags" -t templates-en-US ../l10n/$lang $lang
done
rm $(find $lang -type f | egrep -v "\.po$")

clean_po $langs
