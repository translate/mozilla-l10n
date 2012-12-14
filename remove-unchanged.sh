#!/bin/bash

progress="--progress=none"

langs=$*

for lang in $langs
do
	pofilter $progress -t unchanged $lang $lang-unchanged
	podebug $progress --rewrite=blank $lang-unchanged $lang-unchanged-blank
	pomerge $progress --mergecomments=no -t $lang $lang-unchanged-blank $lang
	rm -rf $lang-unchanged*
done
