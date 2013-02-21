#!/bin/bash

langs=$*

export PYTHONPATH=../tools/translate:$PYTHONPATH
export PATH=../tools/translate/translate/convert:$PATH

for lang in $langs
do
	moz2po --progress=none --exclude=".hgtags" -t ../l10n/en-US ../l10n/$lang $lang
done

./cleanup-msgcat.sh $langs
