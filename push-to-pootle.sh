#!/bin/bash

project=firefox
# Use instance: pootle or testpootle (2.1 and 2.2 instances)
instance=mozilla
langs=$*
user=pootlesync
server=pootle.locamotion.org
local_copy=.pootle_phases_tmp
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


sync_command="$precommand python $manage_command sync_stores --verbosity=${manage_py_verbosity} $option_project $option_langs"
update_command="$precommand python $manage_command update_stores $option_project"
pootle_dir=/var/www/sites/$instance/translations/$project

# Sync project
ssh $user@$server $sync_command

read -p "Do you wish to proceed? Do not if new translations have sync'd for your language." -n1 answer
echo
if [ "$answer" != "y" ]; then
	exit
fi

# Copy files across and disassemble phases
for lang in $langs
do
	rm -rf $local_copy/$lang
	if [ -f "$phaselist" ]; then
		cat $phaselist | while read phase file
		do
			if [ $lang == "pot" -o $lang == "templates" ]; then
				file=${file}t
			fi
			mkdir -p $local_copy/$lang/$phase/$(dirname $file)
			cp -p $lang/$file $local_copy/$lang/$phase/$file
		done
	else
		if [ $lang == "pot" -o $lang == "templates" ]; then
			find $lang -name "*.pot"
		else
			find $lang -name "*.po"
		fi | while read file
		do
			mkdir -p $local_copy/$(dirname $file)
			cp -p $file $local_copy/$file
		done
	fi
done


for lang in $langs
do
	# FIXME only sync if we copied up correctly, this way we catch permission errors quickly
	rsync -az --no-g --chmod=Dg+s,ug+rw,o-rw,Fug+rw,o-rw --include="*.po" --exclude=pootle-terminology.po --exclude=.translation_index --delete $local_copy/$lang $user@$server:$pootle_dir/
	ssh $user@$server "$update_command --language=$lang"
done
