#!/bin/bash

project=firefox
# Use instance: pootle or testpootle (2.1 and 2.2 instances)
instance=mozilla
langs=$*
user=pootlesync
server=pootle.locamotion.org
local_copy=.pootle_tmp
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=2
precommand=". /var/www/sites/mozilla/env/bin/activate;"

option_project="--project=$project"
option_change_id=""

if [ $# -eq 1 ]; then
	option_change_id="--modified-since=$1"
fi

ssh $user@$server $precommand python $manage_command list_languages --verbosity=$manage_py_verbosity $option_project $option_change_id
