#!/bin/bash

progress="--progress=none"

langs=$*

for lang in $langs
do
	pofilter $progress -t unchanged $lang $lang-unchanged
	podebug $progress --rewrite=blank $lang-unchanged $lang-unchanged-blank
	pomerge $progress --mergecomments=no -t $lang $lang-unchanged-blank $lang

	(cd $lang
	git checkout \
	browser/branding/official/brand.dtd.po \
	browser/branding/official/brand.properties.po \
	browser/chrome/browser-region/region.properties.po)

	rm -rf $lang-unchanged*
done

