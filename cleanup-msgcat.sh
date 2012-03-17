#!/bin/bash

for lang in $*
do
	for po in $(find $lang -name "*.po")
	do
		msgcat $po > $po.2 && mv $po.2 $po
	done
done
