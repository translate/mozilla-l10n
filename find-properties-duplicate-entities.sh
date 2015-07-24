#!/bin/bash

if [[ $# -ne 1 ]]; then
	echo "Usage: $(basename $0) [properties file]"
	exit 1
fi

cat $1 | egrep -v "^#" | cut -d "=" -f1 | sed "s/\s*$//" | sort | uniq -d
