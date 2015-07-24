#!/bin/bash

year_month=$1
log=$2

echo "Number of languages"
egrep "^$year_month" $log | grep commit | cut -f 5- | sed "s/ /\n/g" | sort -u | sed "/^$/d" | wc -l
echo

echo "Top 10 commiters"
egrep "^$year_month" $log | grep commit | cut -f 5- | sed "s/ /\n/g" | sort | sed "/^$/d" | uniq -c | sort -nr | head -10
echo

echo "Template updates"
egrep "^$year_month" $log | grep templates
echo

echo "All commiters"
egrep "^$year_month" $log | grep commit | cut -f 5- | sed "s/ /\n/g" | sort | sed "/^$/d" | uniq
echo

echo "Reactivated languages"
for lang in $(egrep "^$year_month" $log | grep commit | cut -f 5- | sed "s/ /\n/g" | sort -u | sed "/^$/d")
do
	active_in_month=$(egrep "\b$lang\b" $log | head -1 | egrep "^$year_month")
	if [[ $active_in_month ]]; then
		echo -n "$lang - "
		echo $active_in_month
		echo -n "    - "
 		git log --until=${year_month}-31 --reverse --pretty="%ai %s (%h)" -- $lang | head -1 
	fi
done
