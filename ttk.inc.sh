#!/bin/bash
#
# Copyright 2008-2013 Translate House
#
# This file is part of the Translate Toolkit.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>.

# Verbosity
# 0: Errors, quiet only report errors
# 1: Warnings
# 2: Info lots of stuff
# 3: Debug - shout it out
opt_verbose=0
opt_yes=""

# FIXME these need to be managed and switched by a --verbose setting
progress=none
errorlevel=traceback
export USECPO=0
hgverbosity="--quiet" # --verbose to make it noisy
gitverbosity="--quiet" # --verbose to make it noisy
pomigrate2verbosity="--quiet"
get_moz_enUS_verbosity=""
easy_install_verbosity="--quiet"
use_color="yes"


############################
# Language and language code
############################

function _remove_alt_src_langs() {
	# Remove alt-src langs
	langs=$*
	for alt in $alt_src
	do
		langs=$(echo $langs | sed "s/\b${alt}\b//")
	done
	echo $langs
}

function which_langs() {
	# Detemine which languages we want to work on. Either:
	# 1) Mutliple specified languages
	# 2) Languages identified by a specific change ID
	# 3) All languages for the project
	#
	# * Special handling of alt-src languages we exclude them unless
	#   specifically mentioned.
	# * We replace alt-src with the languages in our alt-src config
	langs=$*
	if [ $# -eq 0 ]; then
		# None specific so we want tall languages
		langs=$(_remove_alt_src_langs $(all_langs))
	elif [ $# -eq 1 -a -z "${1//[0-9]/}" ]; then
		# Using a modified since number
		langs=$(_remove_alt_src_langs $(all_langs $1))
	fi
	# Substitute alt-src with actual alt-src languages
	langs=${langs/alt-src/$alt_src}
	echo $langs
}

function all_langs() {
	# Retrieves all the languages enabled for the active project
	option_change_id=""
	option_project="--project=$project"
	if [ $# -eq 1 ]; then
		option_change_id="--modified-since=$1"
	fi
	ssh $user@$server $precommand python $manage_command list_languages --verbosity=$manage_py_verbosity $option_project $option_change_id
}

function _get_language_line() {
	_find_config_base_dir
	local queried_lang=$1
	default_mappings=${config_base_dir}/default/languages.txt
	project_mappings=${config_dir}/languages.txt
	for mapping in $project_mappings $default_mappings
	do
		if [ -f $mapping ]; then
			# s/\t/:/ - since BSD sed doens't seem to to manage \t use real {TAB}
			line=$(cat $mapping |
			       egrep -v "^#" |
			       sed "s/	/:/g" |
			       egrep "(^|:|,)${queried_lang}(,|:|$)")
			if [ ! -z $line ]; then
				echo $line
				return 0
			fi
		fi
	done
	echo ${queried_lang}:${queried_lang}
}

function get_language_upstream() {
	# Determine the uptream language from the one supplied
	local queried_lang=$1
	_get_language_line $queried_lang | cut -d":" -f2
}

function get_language_pootle() {
	# Determine the pootle language from the one supplied
	local queried_langs=$*
	local pootle_langs=""
	for lang in $queried_langs
	do
		pootle_langs="$pootle_langs $(_get_language_line $lang | cut -d":" -f1)"
	done
	echo $pootle_langs
}

create_bashlangs() {
	# Converted the list of supplied languages into the bash form
	# e.g. af ach fr -> af,ach,fr
	local langs=$*

	if [ "$(echo $langs | egrep " ")" != "" ]; then
		bashlangs="{$(echo $langs | sed "s/ /,/g")}"
	else
		bashlangs=$langs
	fi
}

_create_option_langs() {
	local langs=$*

	for lang in $langs
	do
		option_langs="$option_langs --language=$lang"
	done
}


#####################
# Pootle interactions
#####################
latest_change_id() {
	ssh $user@$server $precommand python $manage_command revision --verbosity=$manage_py_verbosity
}

sync_stores() {
	log_info "Syncing files to Pootle's filesystem"
	_create_option_langs $(get_language_pootle $*)
	option_project="--project=$project"
	#sync_command="$precommand python $manage_command sync_stores --verbosity=$manage_py_verbosity --overwrite $option_project $option_langs"
	sync_command="$precommand python $manage_command sync_stores --force --overwrite --verbosity=$manage_py_verbosity $option_project $option_langs"
	
	ssh $user@$server $sync_command || exit
	
}

update_against_templates() {
	log_info "Updating languages against templates"
	_create_option_langs $(get_language_pootle $*)
	option_project="--project=$project"
	update_command="$precommand python $manage_command update_against_templates --verbosity=$manage_py_verbosity $option_project $option_langs"
	
	ssh $user@$server $update_command || exit
	
}

rsync_files_get() {
	log_info "rsync copying files on Pootle to local filesystem"
	create_bashlangs $(get_language_pootle $*)
	mkdir -p $local_copy/$project
	pootle_dir=/var/www/sites/$instance/translations/$project
	rsync -az --delete --exclude=".translation_index" --exclude=pootle-terminology.po $user@$server:$pootle_dir/$bashlangs $local_copy/$project/ || exit
}

rsync_files_put() {
	log_info "rsync copying files on local filesystem to Pootle"
	local langs=$(get_language_pootle $*)

	option_project="--project=$project"
	update_command="$precommand python $manage_command update_stores --force $option_project"
	pootle_dir=/var/www/sites/$instance/translations/$project
	
	if [[ $opt_yes ]]; then
		read -p "Do you wish to proceed? Do not if new translations have sync'd for your language." -n1 answer
		echo
		if [ "$answer" != "y" ]; then
			exit
		fi
	fi
	
	assemble_phase $langs

	# FIXME we can probably do this in one go
	log_debug "rsync file to Pootle and update_stores"
	for lang in $langs
	do
		# FIXME only sync if we copied up correctly, this way we catch permission errors quickly
	        log_debug "rsyncing: $lang"
		rsync -az --no-g --chmod=Dg+s,ug+rw,o-rw,Fug+rw,o-rw --include="*.$translation_file_ext" --exclude=pootle-terminology.po --exclude=.translation_index --delete $local_copy/$project/$lang $user@$server:$pootle_dir/
		ssh $user@$server "$update_command --language=$lang"
	done
}

function assemble_phase() {
	# Create phases for a phase baesd sync
	local langs=$(get_language_pootle $*)
	log_debug "Assembling phases"
	for lang in $langs
	do
		rm -rf $local_copy/$project/$lang
		if [ -f "$config_dir/$phaselist" ]; then
			cat $config_dir/$phaselist | while read phase file
			do
				if [ $lang == "pot" -o $lang == "templates" ]; then
					file=${file}t
				fi
				mkdir -p $local_copy/$project/$lang/$phase/$(dirname $file)
				cp -p $translation_dir/$lang/$file $local_copy/$project/$lang/$phase/$file
			done
		else
			(cd $translation_dir/$lang
			if [ $lang == "pot" -o $lang == "templates" ]; then
				find $PRODUCT_DIRS -name "*.$translation_template_ext"
			else
				find $PRODUCT_DIRS -name "*.$translation_file_ext"
			fi) | while read file
			do
				mkdir -p $local_copy/$project/$lang/$(dirname $file)
				cp -p $translation_dir/$lang/$file $local_copy/$project/$lang/$file
			done
		fi
	done
}


disassemble_phase() {
	# Break up a phase based sync into normal structure
	local langs=$(get_language_pootle $*)
	(
	cd $local_copy/$project
	# FIXME bail out early so that we don't report disassembling if there
	# is no phase
	log_info "Disassembling phases"
	for lang in $langs
	do
		log_debug "Language: $lang"
		cd $lang
		if [ -f "$config_dir/$phaselist" ]; then
			for phase in $(ls)
			do
				if [ -d $phase ]; then
			        	cd $phase
			        	log_debug "Phase: $phase"
					for po in $(find . -name "*.$translation_file_ext")
			        	do
					        mkdir -p $translation_dir/$lang/$(dirname $po)
					        cp -p $po $translation_dir/$lang/$po
			        	done
			        	cd ..
				else
					cp -p $phase $translation_dir/$lang
				fi
			done
		else
			for po in $(find . -name "*.$translation_file_ext")
		       	do
				mkdir -p $translation_dir/$lang/$(dirname $po)
				cp -p $po $translation_dir/$lang/$po
		       	done
		fi
		cd ..
	done
	)
	clean_po_location $translation_dir $langs
	revert_unchanged_po_git $translation_dir $langs
}


function clean_po {
	# dirs - one or more directories within which to search for PO files
	local dirs=$*
	require msgcat
	if [ $translation_file_ext != "po" ]; then
		exit
	fi


	# FIXME - only really need to run this is USECPO=0
	log_info "Reflow Gettext PO file formatting"
	for po in $(find $dirs -name "*.$translation_file_ext" -o -name "*.$translation_template_ext")
	do
		if [ -s $po ]; then
			msgcat -o $po.2 $po 2> >(egrep -v "internationali[sz]ed messages should not contain the .* escape sequence" >&2 ) && mv $po.2 $po
		fi
	done
}

function clean_po_location {
	local location=$1
	shift
	local dirs=$*
	(
	cd $location
	clean_po $dirs
	)
}


#########
# Helpers
#########

function require() {
	# Check that a command is in the path
	local commands=$*
	local cmd
	for cmd in $commands
	do
		which $cmd >/dev/null || log_error "Missing tool: $cmd"
	done

}

#######################
# Language config files
#######################

function _search_language_config() {
	# Find if a feature is present
	local language=$1
	local searchstring=$2
	local field=$3
	[ -f $config_dir/language_config.txt ] &&
	cat $config_dir/language_config.txt |
	egrep -v "^#" |
	egrep "^$language	" |
	cut -d"	" -f$field |
	egrep $searchstring
}

function check_permission() {
	# Check that we have permission to execute this
	local language=$1
	local user=$(whoami)
	if [ ! -f $config_dir/language_config.txt -o "$(_search_language_config $language $user 2)" ]; then
		echo "yes"
	fi
}

function should_build() {
	local language=$1
	local target=$2
	if [ "$(_search_language_config $language $target 3)" ]; then
		echo "yes"
	fi
}

#########
# Logging
#########

# TODO - introduce some sense of INFO, DEBUG, ERROR
# TODO - move the variables to set this into the common folder.
function logger() {
	# Log to the console
	local level=$1
	shift
	local msg=$*

	red=31
	green=32
	blue=34
	purple=35

	if [ $use_color ]; then
		case $level in
			'debug')
				color=$purple
				;;
			'info')
				color=$green
				;;
			'warning'|'error')
				color=$red
				;;
			'red')
				color=$red
				;;
			'green')
				color=$green
				;;
			'blue')
				color=$blue
				;;
			'purple')
				color=$purple
				;;
		esac
		case $level in
			'debug'|'info'|'warning'|'error')
				echo -e "\033[${color}m${level}:\033[0m $msg"
				;;
			*)
				label=$1
				shift
				msg=$*
				echo -e "\033[${color}m${label}:\033[0m $msg"
				;;
		esac
	else
		echo "${level}: $msg"
	fi
}

function log() {
	local level=$1
	shift
	local msg=$*
	case $level in
		'debug')
			if [ $opt_verbose -lt 3 ]; then
				return 0
			fi
			;;
		'info')
			if [ $opt_verbose -lt 2 ]; then
				return 0
			fi
			;;
		'warning')
			if [ $opt_verbose -lt 1 ]; then
				return 0
			fi
			;;
		'error')
			;;
		*)
			msg="Unknown log level '$level'"
			level='error'
	esac
	logger $level $msg	
	if [ $level = "error" ]; then
		exit 1
	fi
}


function verbose() {
	# Alias for log_info
	log_info $*
}

function log_debug() {
	log 'debug' $*
}

function log_info() {
	log 'info' $*
}

function log_warning() {
	log 'warning' $*
}

function log_error() {
	log 'error' $*
}


##### log_file #########

function _log_file_vars {
	_find_config_base_dir
	log_file_prefix=LOG_
	log_filename=${log_file_prefix}$(workon_current)
	log_file=$base_dir/${log_filename}
}

function logger_file() {
	_log_file_vars
	isodate=$(date --iso=seconds)
	spacer="\t"
	columns=$isodate
	for column in $*
	do
		if [[ $column == '{' ]]; then
			columns=$(echo -n "${columns}${spacer}")
			spacer=" "
			continue
		elif [[ $column == '}' ]]; then
			spacer="\t"
			continue
		fi
		columns=$(echo -n "${columns}${spacer}${column}")
	done
	echo -e ${columns} >> $log_file
}


# Config loading
function _find_config_base_dir() {
	# Find the $config_dir directory from the current place	
	if [ "$config_base_dir" = "" ]; then
		local config_dir_name=".ttk"
		cdir=$(pwd)
		while [ ! -d $cdir/$config_dir_name ]
		do
			if [ $cdir = "/" ]; then
				log_error "Can't find $config_dir_name"
			fi
			cdir=$(dirname $cdir)
		done
		config_base_dir=$cdir/$config_dir_name
		base_dir=$cdir
	fi
}

function workon() {
	# Define what project is being worked on so you don't need to run
	# --config
	local config_project=$1
	_find_config_base_dir
	config_dir=$config_base_dir/$config_project
	if [ ! -d $config_base_dir/$config_project ]; then
		log_error "Error: can't find $config_dir"
	fi
	rm -f $config_base_dir/*.workon
	touch $config_base_dir/${config_project}.workon
}

function workon_list() {
	# List all the current settings
	_find_config_base_dir
	echo "Project configs:"
	(cd $config_base_dir; ls -1 */config.sh | cut -d"/" -f1 | egrep -v "default")
	logger green "Default" "$(basename $(ls $config_base_dir/*.default 2>/dev/null || echo "None.default") .default)"
	logger red "Current acive" "$(basename $(ls $config_base_dir/*.workon 2>/dev/null || echo "None.workon") .workon)"
}

function workon_current() {
	# Find the currently active workon project
	echo $(basename $(ls $config_base_dir/*.workon 2>/dev/null || echo "None.workon") .workon)
}

function source_config() {
	_find_config_base_dir
	local workon=$(ls $config_base_dir/*.workon 2>/dev/null)
	local default=$(ls $config_base_dir/*.default 2>/dev/null)
	if [ -f "$workon" ]; then
		config_dir=$config_base_dir/$(basename $workon .workon)
	elif [ -f "$default" ]; then
		config_dir=$config_base_dir/$(basename $default .default)
	else
		log_error "No default or workon project.  Create at least a default project now."
	fi
	if [ -f $config_dir/config.sh ]; then
		source $config_dir/config.sh
	else
		log_error "Missing log file $config_dir/config.sh"
	fi
}

function source_script() {
	script=$1
	_find_config_base_dir
	local workon=$(ls $config_base_dir/*.workon 2>/dev/null)
	local default=$(ls $config_base_dir/*.default 2>/dev/null)
	possible_config_dirs=""
	if [ -f "$workon" ]; then
		possible_config_dirs="$possible_config_dirs $config_base_dir/$(basename $workon .workon)"
	fi
	if [ -f "$default" ]; then
		possible_config_dirs="$possible_config_dirs $config_base_dir/$(basename $default .default)"
	fi
	possible_config_dirs="$possible_config_dirs $config_base_dir/default"
	for possible in $possible_config_dirs
	do
		if [ -f $possible/$script ]; then
			found=$possible/$script
			echo $found
			return 0
		fi
	done
	if [ ! $found ]; then
		log_error "No script '$script' found."
	fi
}

#################
# Version Control
#################

function revert_unchanged_po_git {
	# Revert changes to PO files that are only header changes
	local location=$1
	shift
	local dirs=$*
	if [ $translation_file_ext != "po" ]; then
		exit
	fi

	log_info "Revert files that only have header changes"
	log_debug "Reverting in '$location' for '$dirs'"
	(cd $location
	for dir in $dirs
	do
		log_debug "Reverting files in '$dir'"
		[ "$(git status --porcelain ${dir})" != "?? ${dir}/" ] && git checkout $gitverbosity -- $(git difftool -y -x 'diff --unified=3 --ignore-matching-lines=POT-Creation --ignore-matching-lines=X-Generator --ignore-matching-lines="#. extracted from" -s' ${dir} |
		egrep "are identical$" |
		sed "s/^Files.*.\.po[t]\? and //;s/\(\.po[t]\?\).*/\1/") || echo "No header only changes, so no reverts needed"
	done
	)
}


function vc_addremove_git {
	# Add and remove (obsolete) translation files
	# FIXME make this more generic so that you can somehow get and set
	# PRODUCT_DIRS
	local location=$1
	local dir=$2
	verbose "Move old files to obsolete/ and add new files"
	if [ "$(git status --porcelain ${dir})" == "?? ${dir}/" ]; then
		# Not VC managed, assume it's a new language
		# FIXME does this actually work? Surely we need to traverse the
		# folder? or don't need the *.po bit
		git add ${dir}/\*.$translation_file_ext
	else
		(cd ${location}/${dir}
		for newfile in $(git status --porcelain $PRODUCT_DIRS | egrep "^\?\?" | sed "s/^??\w*[^\/]*\///")
		do
			if [ -f $newfile -a "$(basename $newfile | cut -d"." -f3)" = "po" ]; then
				git add $newfile
			elif [ -d $newfile -a "$(find $newfile -name "*.$translation_file_ext" -o -name "*.$translation_template_ext")" ]; then
				git add $newfile
			fi
		done

		for oldfile in $(git status --porcelain $PRODUCT_DIRS $RETIRED_PRODUCT_DIRS | egrep "^ D" | sed "s/^ D\w*[^\/]*\///")
		do
			if [ "$(basename $oldfile | cut -d'.' -f3 | cut -c-2)" = "po" ]; then
				git checkout $gitverbosity -- $oldfile
				mkdir -p obsolete/$(dirname $oldfile)
				git mv -f $oldfile obsolete/$oldfile || log_warning "obsolete/$oldfile - already exists"
			fi
		done
		clean_po obsolete
		)
	fi
}

function get_hash() {
	# Get the hash value for a version control system
	# FIXME - need to make other hashes for other VC systems
	local location=$1
	cd $location
	git rev-parse --short HEAD
}


#####################################
# Copying files from source to target
#####################################

# TODO - abstract the source and target directories so they don't have build in
# assumptions e.g. $SOURCE rather then $L10N_ENUS 
function copyfile {
	filename=$1
	language=$2
	directory=$(dirname $filename)
	if [ -f ${L10N_ENUS}/$filename ]; then
		mkdir -p ${L10N_DIR}/$language/$directory
		cp -p ${L10N_ENUS}/$filename ${L10N_DIR}/$language/$directory
	fi
}

function copyfileifmissing {
	filename=$1
	language=$2
	if [ ! -f ${L10N_DIR}/$language/$filename ]; then
		copyfile $1 $2
	fi
}

function copyfiletype {
	filetype=$1
	language=$2
	files=$(cd ${L10N_ENUS}; find . -name "$filetype")
	for file in $files
	do
		copyfile $file $language
	done
}

function copydir {
	dir=$1
	language=$2
	if [ -d ${L10N_ENUS}/$dir ]; then
		files=$(cd ${L10N_ENUS}/$dir && find . -type f)
		for file in $files
		do
			copyfile $dir/$file $language
		done
	fi
}

########### cron locks ##############

function _lock_vars {
	_find_config_base_dir
	running_file_prefix=RUNNING_
	running_file=$base_dir/${running_file_prefix}$(basename $0)
	emergency_stop=$base_dir/STOP
}

function stop_if_running {
	_lock_vars
	if [[ -f $emergency_stop ]]; then
		echo "Emergency stop in place"
		exit 1
	fi
	if [[ $(find $base_dir -maxdepth 1 -name "$running_file_prefix*") ]]; then
		echo "Already running: $(find $base_dir -name "${running_file_prefix}*")"
		exit 1
	fi
}

function mk_lock_file {
	_lock_vars
	touch $running_file
}

function rm_lock_file {
	_lock_vars
	rm $running_file
}


###### Last Commit ############


function _last_commit_vars {
	_find_config_base_dir
	last_commit_file_prefix=LAST_COMMIT_
	last_commit_filename=LAST_COMMIT_$(workon_current)_$(basename $0)
	last_commit_file=$base_dir/${last_commit_filename}
}

function stop_if_no_last_commit {
	_last_commit_vars
	if [[ -z $(find $base_dir -maxdepth 1 -name "$last_commit_filename") ]]; then
		echo "No last commit: please manually setup $last_commit_file"
		exit 1
	fi
}

function mk_new_commit_file {
	_last_commit_vars
	new_commit_file=$(mktemp)
	latest_change_id > $new_commit_file
}

function update_last_commit_file {
	_last_commit_vars
	mv $new_commit_file $last_commit_file
}

####### Standard Settings #############
# Standard file locations
_find_config_base_dir
translation_dir=$base_dir
templates=$translation_dir/templates

# Standard settings
translation_file_ext=po
translation_template_ext=pot
PRODUCT_DIRS=.
phaselist=

##### MAIN #####
source_config 

