#!/bin/bash

project=firefox
# Use instance: pootle or testpootle (2.1 and 2.2 instances)
instance=pootle
langs=$*
user=pootlesync
local_copy=.pootle_phases_tmp
phaselist=firefox.phaselist

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

option_project="--project=$project"

sync_command="python /var/www/sites/$instance/Pootle/manage.py sync_stores $option_project $option_langs"
update_command="python /var/www/sites/$instance/Pootle/manage.py update_stores $option_project"
pootle_dir=/var/www/sites/$instance/podirectory/$project

# Sync project
ssh $user@pootle.locamotion.org $sync_command

read -p "Do you wish to proceed? Do not if new translations have sync'd for your language." -N1 answer
if [ "$answer" != "y" ]; then
	exit
fi

# Copy files across and disassemble phases
for lang in $langs
do
	rm -rf $local_copy/$lang
	cat $phaselist | while read phase file
	do
		mkdir -p $local_copy/$lang/$phase/$(dirname $file)
		cp -p $lang/$file $local_copy/$lang/$phase/$file
	done
done


for lang in $langs
do
	# FIXME only sync if we copied up correctly, this way we catch permission errors quickly
	rsync -az --no-g --no-p --chmod=Dg+s,ug+rw,o-rw,Fug+rw,o-rw --include="*.po" --delete $local_copy/$lang $user@pootle.locamotion.org:$pootle_dir/
	ssh $user@pootle.locamotion.org "$update_command --language=$lang"
done
