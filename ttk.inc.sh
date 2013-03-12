#!/bin/bash

# Verbosity
# 0: Errors, quiet only report errors
# 1: Warnings
# 2: Info lots of stuff
# 3: Debug - shout it out
opt_verbose=0

# FIXME these need to be managed and seitched by a --verbose setting
progress=none
errorlevel=traceback
export USECPO=0
hgverbosity="--quiet" # --verbose to make it noisy
gitverbosity="--quiet" # --verbose to make it noisy
pomigrate2verbosity="--quiet"
get_moz_enUS_verbosity=""
easy_install_verbosity="--quiet"


function all_langs() {
	# Retrieves all the languages enabled for the active project
	option_change_id=""
	option_project="--project=$project"
	if [ $# -eq 1 ]; then
		option_change_id="--modified-since=$1"
	fi
	ssh $user@$server $precommand python $manage_command list_languages --verbosity=$manage_py_verbosity $option_project $option_change_id
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

sync_stores() {
	local langs=$*
	_create_option_langs $langs
	sync_command="$precommand python $manage_command sync_stores --verbosity=$manage_py_verbosity $option_project $option_langs"
	
	ssh $user@$server $sync_command || exit
	
}
rsync_files_get() {
	local langs=$*

	create_bashlangs $langs
	mkdir -p $local_copy/$project
	pootle_dir=/var/www/sites/$instance/translations/$project
	rsync -az --delete --exclude=".translation_index" --exclude=pootle-terminology.po $user@$server:$pootle_dir/$bashlangs $local_copy/$project/ || exit
}

rsync_files_put() {
	local langs=$*

	update_command="$precommand python $manage_command update_stores $option_project"
	pootle_dir=/var/www/sites/$instance/translations/$project
	
	read -p "Do you wish to proceed? Do not if new translations have sync'd for your language." -n1 answer
	echo
	if [ "$answer" != "y" ]; then
		exit
	fi
	
	# Copy files across and disassemble phases
	for lang in $langs
	do
		rm -rf $local_copy/$lang
		if [ -f "$config_dir/$phaselist" ]; then
			cat $config_dir/$phaselist | while read phase file
			do
				if [ $lang == "pot" -o $lang == "templates" ]; then
					file=${file}t
				fi
				mkdir -p $local_copy/$lang/$phase/$(dirname $file)
				cp -p $lang/$file $local_copy/$lang/$phase/$file
			done
		else
			(cd $lang
			if [ $lang == "pot" -o $lang == "templates" ]; then
				find $PRODUCT_DIRS -name "*.pot"
			else
				find $PRODUCT_DIRS -name "*.po"
			fi) | while read file
			do
				mkdir -p $local_copy/$lang/$(dirname $file)
				cp -p $lang/$file $local_copy/$lang/$file
			done
		fi
	done
	
	
	for lang in $langs
	do
		# FIXME only sync if we copied up correctly, this way we catch permission errors quickly
		rsync -az --no-g --chmod=Dg+s,ug+rw,o-rw,Fug+rw,o-rw --include="*.po" --exclude=pootle-terminology.po --exclude=.translation_index --delete $local_copy/$lang $user@$server:$pootle_dir/
		ssh $user@$server "$update_command --language=$lang"
	done
}

disassemble_phase() {
	# Break up a phase baesd sync into normal structure
	local langs=$*
	(
	cd $local_copy/$project
	for lang in $langs
	do
		log_info "Language: $lang"
		cd $lang
		if [ -f "$config_dir/$phaselist" ]; then
			for phase in $(ls)
			do
				if [ -d $phase ]; then
			        	cd $phase
			        	log_info "Phase: $phase"
			        	for po in $(find . -name "*.po")
			        	do
			        	        mkdir -p $local_trans_dir/$lang/$(dirname $po)
			        	        mv $po $local_trans_dir/$lang/$po
			        	done
			        	cd ..
				else
					mv $phase $local_trans_dir/$lang
				fi
			done
		else
		       	for po in $(find . -name "*.po")
		       	do
		       	        mkdir -p $local_trans_dir/$lang/$(dirname $po)
		       	        mv $po $local_trans_dir/$lang/$po
		       	done
		fi
		cd ..
	done
	)
	clean_po_location $local_trans_dir $langs
	revert_unchanged_po_git $local_trans_dir $langs
}


function clean_po {
	# dirs - one or more directories within which to search for PO files
	local dirs=$*
	require msgcat

	# FIXME - only really need to run this is USECPO=0
	log_info "Cleanup - fix Gettext PO file formatting using msgcat"
	for po in $(find $dirs -name "*.po" -o -name "*.pot")
	do
		msgcat -o $po.2 $po 2> >(egrep -v "internationali[sz]ed messages should not contain the .* escape sequence" >&2 ) && mv $po.2 $po
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


# Helpers

function require() {
	# Check that a command is in the path
	local commands=$*
	local cmd
	for cmd in $commands
	do
		which $cmd >/dev/null || log_error "Missing: $cmd"
	done

}

# Logging
# TODO - introduce some sense of INFO, DEBUG, ERROR
# TODO - move the variables to set this into the common folder.
function logger() {
	# Log to the console
	local level=$1
	local msg=$2

	# FIXME do the colour highlighting and timing again
	#if [ "$opt_time" ]; then
	#	info_color=32 # Green
	#	time_color=34 # Blue
	#	end_time=$(date +%s)
	#	time_diff=$(($end_time - $start_time))
	#	echo -e "\033[${info_color}mINFO:\033[0m $1 [previous step \033[${time_color}m$time_diff sec\033[0m]"
	#	start_time=$end_time
	#fi
	echo "${level}: $msg"
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
	log 'debug' $1
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
	(cd $config_base_dir; ls -1p | egrep "/" | cut -d"/" -f1)
	echo "Current acive: $(basename $(ls $config_base_dir/*.workon 2>/dev/null || echo "None.workon") .workon)"
	echo "Default: $(basename $(ls $config_base_dir/*.default 2>/dev/null || echo "None.default") .default)"
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

# Version Control

function revert_unchanged_po_git {
	# Revert changes to PO files that are only header changes
	local location=$1
	shift
	local dirs=$*

	log_info "Migration cleanup - revert files with only PO header changes"
	(cd $location
	for dir in $dirs
	do
		[ "$(git status --porcelain ${dir})" != "?? ${dir}/" ] && git checkout $gitverbosity -- $(git difftool -y -x 'diff --unified=3 --ignore-matching-lines=POT-Creation --ignore-matching-lines=X-Generator --ignore-matching-lines="#. extracted from" -s' ${dir} |
		egrep "are identical$" |
		sed "s/^Files.*.\.po[t]\? and //;s/\(\.po[t]\?\).*/\1/") || echo "No header only changes, so no reverts needed"
	done
	)
}



##### MAIN #####
source_config 

