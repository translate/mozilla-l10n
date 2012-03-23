#!/bin/bash

project=firefox
# Use instance: pootle or testpootle (2.1 and 2.2 instances)
instance=pootle
langs=$*
user=pootlesync
local_copy=.pootle_tmp

if [ $# -lt 1 ]; then
	echo "$(basename $0) [lang(s)]"
	exit
fi

if [ $# -eq 1 ]; then
	bashlangs=$langs
else
	bashlangs="{$(echo $langs | sed "s/ /,/g")}"
fi

for lang in $langs
do
	option_langs="$option_langs --language=$lang"
done

for lang in $langs
do
	if [ -d $lang/.svn -o ! -d $lang ]; then
		svn up $lang
	fi
done

option_project="--project=$project"

sync_command="python /var/www/sites/$instance/Pootle/manage.py sync_stores $option_project $option_langs"
pootle_dir=/var/www/sites/$instance/podirectory/$project

# Sync project
ssh $user@pootle.locamotion.org $sync_command || exit

# Copy files across and disassemble phases
mkdir -p $local_copy/$project
rsync -az --delete --exclude=".translation_index" $user@pootle.locamotion.org:$pootle_dir/$bashlangs $local_copy/$project/ || exit

svndir=$(pwd)
cd $local_copy/$project
for lang in $langs
do
	echo "Language: $lang"
	cd $lang
	for phase in $(ls)
	do
	        cd $phase
	        echo "Phase: $phase"
	        for po in $(find . -name "*.po")
	        do
	                mkdir -p $svndir/$lang/$(dirname $po)
	                mv $po $svndir/$lang/$po
	        done
	        cd ..
	done
	cd ..
done
cd ../..

# Cleanup
./cleanup-msgcat.sh $langs
