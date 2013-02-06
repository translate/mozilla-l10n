#!/bin/bash

project=firefox
# Use instance: pootle or testpootle (2.1 and 2.2 instances)
instance=mozilla
langs=$*
user=pootlesync
server=pootle.locamotion.org
local_copy=.pootle_tmp
phaselist=firefox.phaselist
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=2
precommand=". /var/www/sites/mozilla/env/bin/activate;"

option_project="--project=$project"

if [ $# -eq 0 ]; then
	langs=$(ssh $user@$server $precommand python $manage_command list_languages --verbosity=$manage_py_verbosity $option_project)
fi

if [ "$(echo $langs | egrep " ")" != "" ]; then
	bashlangs="{$(echo $langs | sed "s/ /,/g")}"
else
	bashlangs=$langs
fi

for lang in $langs
do
	option_langs="$option_langs --language=$lang"
done

git stash --quiet
git pull --rebase
git checkout
git stash pop --quiet


sync_command="$precommand python $manage_command sync_stores --verbosity=$manage_py_verbosity $option_project $option_langs"
pootle_dir=/var/www/sites/$instance/translations/$project

# Sync project
ssh $user@$server $sync_command || exit

# Copy files across and disassemble phases
mkdir -p $local_copy/$project
rsync -az --delete --exclude=".translation_index" --exclude=pootle-terminology.po $user@$server:$pootle_dir/$bashlangs $local_copy/$project/ || exit

svndir=$(pwd)
cd $local_copy/$project
for lang in $langs
do
	echo "Language: $lang"
	cd $lang
	if [ -f "$svndir/$phaselist" ]; then
		for phase in $(ls)
		do
			if [ -d $phase ]; then
		        	cd $phase
		        	echo "Phase: $phase"
		        	for po in $(find . -name "*.po")
		        	do
		        	        mkdir -p $svndir/$lang/$(dirname $po)
		        	        mv $po $svndir/$lang/$po
		        	done
		        	cd ..
			else
				mv $phase $svndir/$lang
			fi
		done
	else
	       	for po in $(find . -name "*.po")
	       	do
	       	        mkdir -p $svndir/$lang/$(dirname $po)
	       	        mv $po $svndir/$lang/$po
	       	done
	fi
	cd ..
done
cd ../..

# Cleanup
./cleanup-msgcat.sh $langs
