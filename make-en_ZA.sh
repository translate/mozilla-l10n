#!/bin/bash

# First deal with the untranslated strings
pofilter --progress=none -t untranslated en_ZA en_ZA-untrans
sed -i "/^# (pofilter)/d" $(find en_ZA-untrans -name "*.po")
podebug --progress=none --rewrite=en en_ZA-untrans en_ZA-untrans-en
pofilter --progress=none -t musttranslatewords --musttranslatefile=words-must-en_ZA en_ZA-untrans-en en_ZA-untrans-en-must
vim $(find en_ZA-untrans-en-must -name "*.po")
pomerge --progress=none -t en_ZA-untrans-en en_ZA-untrans-en-must en_ZA-untrans-en
pomerge --progress=none -t en_ZA en_ZA-untrans-en en_ZA

# Now the fuzzues
pofilter --progress=none -t isfuzzy en_ZA en_ZA-fuzzy
sed -i "/^# (pofilter)/d" $(find en_ZA-fuzzy -name "*.po")
for po in $(find en_ZA-fuzzy -name "*.po")
do
	msgattrib --clear-fuzzy $po > $po.2
	mv $po.2 $po
done
podebug --progress=none --rewrite=en en_ZA-fuzzy en_ZA-fuzzy-en
pofilter --progress=none -t musttranslatewords --musttranslatefile=words-must-en_ZA en_ZA-fuzzy-en en_ZA-fuzzy-en-must
vim $(find en_ZA-fuzzy-en-must -name "*.po")
pomerge --progress=none -t en_ZA-fuzzy-en en_ZA-fuzzy-en-must en_ZA-fuzzy-en
pomerge --progress=none -t en_ZA en_ZA-fuzzy-en en_ZA

rm -rf en_ZA-fuzzy* en_ZA-untrans*
