#!/bin/bash

progress="--progress=none"

langs=$*

for lang in $langs
do
	pofilter --mozilla $progress -t unchanged $lang $lang-unchanged
	podebug $progress --rewrite=blank $lang-unchanged $lang-unchanged-blank
	pomerge $progress --mergecomments=no -t $lang $lang-unchanged-blank $lang

	(cd $lang
	git checkout \
	browser/chrome/branding/brand.dtd.po \
	browser/chrome/branding/brand.properties.po \
	browser/branding/official/brand.dtd.po \
	browser/branding/official/brand.properties.po \
	toolkit/chrome/global-region/region.dtd.po \
	mobile/chrome/region.properties.po
	browser/chrome/browser-region/region.properties.po \
	toolkit/chrome/global/intl.properties.po \
	browser/chrome/browser/aboutRobots.dtd.po \
	dom/chrome/global.dtd.po)

	rm -rf $lang-unchanged*
done

