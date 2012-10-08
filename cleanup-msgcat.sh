#!/bin/bash

for lang in $*
do
	for po in $(find $lang -name "*.po")
	do
		msgcat -o $po.2 $po 2> >(egrep -v "internationali[sz]ed messages should not contain the .* escape sequence" >&2) && mv $po.2 $po
	done
done
