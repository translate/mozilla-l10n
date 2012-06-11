#!/bin/bash

# Make sure we're up-to-date
svn up en_ZA

function process()
{
	testtype=$1
	pofilter --progress=none -t $testtype en_ZA en_ZA-$testtype
	sed -i "/^# (pofilter)/d" $(find en_ZA-$testtype -name "*.po")
	for po in $(find en_ZA-$testtype -name "*.po")
	do
		msgattrib --clear-fuzzy $po > $po.2
		mv $po.2 $po
	done
	podebug --progress=none --rewrite=en en_ZA-$testtype en_ZA-$testtype-en
	pofilter --progress=none -t musttranslatewords --musttranslatefile=words-must-en_ZA en_ZA-$testtype-en en_ZA-$testtype-en-must
	vim $(find en_ZA-$testtype-en-must -name "*.po")
	sed -i "/^# (pofilter)/d" $(find en_ZA-$testtype-en-must -name "*.po")
	pomerge --progress=none -t en_ZA-$testtype-en en_ZA-$testtype-en-must en_ZA-$testtype-en
	pomerge --progress=none -t en_ZA en_ZA-$testtype-en en_ZA
	#rm -rf en_ZA-$testtype*
}

process untranslated
process isfuzzy
