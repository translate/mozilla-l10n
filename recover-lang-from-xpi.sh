#!/bin/bash

xpi=$1
lang=$(basename $xpi .xpi)
l10n_dir=../l10n
merge_dir=$l10n_dir/xpi_recovery
po_dir=$(pwd)

if [ $# -ne 1 ]; then
	echo "Usage: $(basename $0) <xpi>"
	echo "E.g. $(basename $0) shn.xpi"
	exit 1
fi

# Prepare unzip XPI files
# TODO deal with jars if they exist
rm -rf $merge_dir/$lang
mkdir -p $merge_dir/$lang
unzip -q -u -d $merge_dir/$lang "$xpi"

# Check we have an en-US XPI to merge against
version=$(egrep "em:version" $merge_dir/$lang/install.rdf | cut -d'"' -f2)
if [ ! -f "$merge_dir/en-US/en-US-$version.xpi" ]; then
	echo "Please download an en-US.xpi to $$merge_dir/en-US/$version/en-US.xpi"
	echo "Try: wget ftp://ftp.mozilla.org/pub/mozilla.org/firefox/releases/${version}/linux-i686/xpi/en-US.xpi"
	echo "Please also add it to version control"
	exit 1
fi

rm -rf $merge_dir/en-US/$version
unzip -q -u -d $merge_dir/en-US/$version $merge_dir/en-US/en-US-$version.xpi

for rename_lang in $lang en-US
do
	(cd $merge_dir/$rename_lang
	for dir in $(find -type d | egrep "${rename_lang}$" | sort --reverse)
	do
		mv $dir $(dirname $dir)/lang-REG
	done
	)
done

# Make sure we have the Mercurial repo updated
(cd $l10n_dir; ./get-and-reset-lang.sh $lang)

# Do a normal recovery
(cd $merge_dir; moz2po --progress=none -t en-US/$version $lang $po_dir/$lang-xpi-1st)
./remove-unchanged.sh $lang-xpi-1st
pocount $po_dir/$lang-xpi-1st | tail

# Migrate to latest templates and structure
pomigrate2 --quiet --pot2po $lang-xpi-1st $lang templates
./cleanup-msgcat.sh $langs

# Remove any non-PO files
rm $(find $lang -type f | egrep -v "\.po$")

#rm -rf ../l10n/$lang-tmp

# TODO update to latest templates

pocount $lang | tail
