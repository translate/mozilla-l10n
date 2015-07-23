#!/bin/bash -e
#
# Copyright 2009 João Miguel Neves <joao.neves@intraneia.com>
# Copyright 2008 Zuza Software Foundation
#
# This file is part of Translate.
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

##########################################################################
# NOTE: Documentation regarding (the use of) this script can be found at #
# http://translate.sourceforge.net/wiki/toolkit/mozilla_l10n_scripts     #
##########################################################################

source ttk.inc.sh

opt_vc=""
opt_build_xpi="yes"
opt_tarball=""
opt_compare_locales="yes"
opt_copyfiles="yes"
opt_time=""

hgverbosity="--quiet" # --verbose to make it noisy
gitverbosity="--quiet" # --verbose to make it noisy
pomigrate2verbosity="--quiet"
get_moz_enUS_verbosity=""
easy_install_verbosity="--quiet"
tar_verbosity=""


for option in $*
do
	if [ "${option##-*}" != "$option" ]; then
		case $option in
			--xpi)
				opt_build_xpi="yes"
			;;
			--no-xpi)
				opt_build_xpi="no"
			;;
			--tarball)
				opt_tarball="yes"
			;;
			--no-tarball)
				opt_tarball="no"
			;;
			--vc)
				opt_vc="yes"
			;;
			--no-compare-locales)
				opt_compare_locales=""
			;;
			--no-copyfiles)
				opt_copyfiles=""
			;;
			--verbose)
				opt_verbose=3
				hgverbosity="--verbose"
				gitverbosity=""
				progress=bar
				pomigrate2verbosity=""
				get_moz_enUS_verbosity="-v"
				easy_install_verbosity="--verbose"
				tar_verbosity="v"
			;;
			--time)
				opt_time="yes"
			;;
			*) 
			echo "Unkown option: $option"
			exit
			;;
		esac
		shift
	else
		break
	fi
done

LANGS=$(which_langs $*)
log_info "Processing languages '$LANGS'"

for lang in $LANGS
do
	if [ ! "$(check_permission $lang)" ]; then
		log_warning "You do not have permission to work on '$lang' please check"
	fi
	if [ "$lang" == "templates" ]; then
		opt_vc="yes"
	fi
done

# Check requirements:
# FIXME we don't check if we're using language_options.txt
require git hg moz2po po2moz get_moz_enUS.py pomigrate2
[ opt_compare_locales ] && require compare-locales
[ "opt_build_xpi" != "no" ] && require buildxpi.py
[ "opt_tarball" != "no" ] && require tar


# FIXME lets make this the execution directory
_find_config_base_dir
BUILD_DIR="${base_dir}/build"
SOURCE_DIR="${base_dir}/source"
# FIXME rename this
MOZCENTRAL_DIR="${SOURCE_DIR}/${MOZ_REPO}"
PO_DIR="${base_dir}"
L10N_DIR="${BUILD_DIR}/${L10N_VER}"
L10N_ENUS="${PO_DIR}/templates-en-US"
POT_DIR="${PO_DIR}/templates"
LANGPACK_DIR="/var/www/sites/mozilla/translations/POOTLE_EXPORT"
TARBALL_DIR="${BUILD_DIR}/tarball"

if [ $opt_vc ]; then
	verbose "${MOZ_REPO} - update/pull using Mercurial"
	if [ -d "${MOZCENTRAL_DIR}/.hg" ]; then
		cd ${MOZCENTRAL_DIR}
		hg pull $hgverbosity -u
		hg update $hgverbosity -C
	else
		hg clone $hgverbosity http://hg.mozilla.org/releases/${MOZ_REPO}/ ${MOZCENTRAL_DIR}
	fi
fi

if [ "$opt_vc" -o ! -d "${PO_DIR}" ]; then
	verbose "Translations - prepare the parent directory po/"
	for trans_repo in ${PO_DIR}
	do
		if [ -d $trans_repo ]; then
			(cd $trans_repo
			git stash $gitverbosity
			git pull $gitverbosity --rebase
			git checkout $gitverbosity
			git stash pop $gitverbosity || true)
		else
			git clone $gitverbosity git@github.com:translate/mozilla-l10n.git $trans_repo || git clone $gitverbosity git://github.com/translate/mozilla-l10n.git $trans_repo
		fi
	done
fi

verbose "Localisations - update Mercurial-managed languages in ${L10N_DIR}"
mkdir -p ${L10N_DIR}
cd ${L10N_DIR}
for lang in ${LANGS}
do
	mozlang=$(get_language_upstream $lang)
	if [ $opt_vc ]; then
		verbose "Update ${L10N_DIR}/$mozlang"
		if [ -d ${mozlang} ]; then
			if [ -d ${mozlang}/.hg ]; then
			        (cd ${mozlang}
				hg revert $hgverbosity --no-backup --all -r default
				hg pull $hgverbosity -u
				hg update $hgverbosity -C)
			else
			        rm -rf ${mozlang}/* 
			fi
		else
		    hg clone $hgverbosity http://hg.mozilla.org/releases/l10n/${MOZ_DIR}/${mozlang} ${mozlang} || mkdir ${mozlang}
		fi
	fi
done

if [ $opt_vc ]; then
	verbose "Extract the en-US source files from the repo into localisation structure"
	for pdir in ${PRODUCT_DIRS} ${RETIRED_PRODUCT_DIRS}
	do
		rm -rf ${POT_DIR}/$pdir ${L10N_ENUS}/$pdir
	done
	rm -rf ${PO_DIR}/en-US
	get_moz_enUS.py $get_moz_enUS_verbosity -s ${MOZCENTRAL_DIR} -d ${PO_DIR} -p ${MOZ_PRODUCT}
	for pdir in ${PRODUCT_DIRS}
	do
		mkdir -p  ${L10N_ENUS}/$pdir
		mv ${PO_DIR}/en-US/$pdir/* ${L10N_ENUS}/$pdir/
	done
	rm -rf ${PO_DIR}/en-US
	# Remove files from template-en-US that we don't want to maintain and
	# that we don't need for langpack building
	for rmfile in \
		      browser/searchplugins/list.txt \
		      browser/searchplugins/metrolist.txt \
		      mobile/chrome/region.properties \
		      mail/chrome/messenger-region/region.properties \
                      suite/chrome/common/region.properties \
                      suite/chrome/browser/region.properties \
                      suite/chrome/mailnews/region.properties
	do
		rm -f ${L10N_ENUS}/${rmfile}
	done
	
	verbose "moz2po - Create POT files from en-US"
	#for exclude in $RETIRED_PRODUCT_DIRS $OTHER_EXCLUDED_DIRS ".hg"
	#do
	#	excludes="$excludes --exclude=$exclude"
	#done
	(cd ${L10N_ENUS}
	moz2po --errorlevel=$errorlevel --progress=$progress $excludes -P --duplicates=msgctxt . ${POT_DIR}
	)
	# Remove files that we don't want to translate, but that we need for
	# language packs. I.e. remove the .pot but keep the source file.
	for rmpot in \
                      browser/chrome/browser-region/region.properties.pot
	do
		rm -f ${POT_DIR}/${rmpot}
	done
	if [ $USECPO -eq 0 ]; then
		(cd ${POT_DIR}
		clean_po ${PRODUCT_DIRS}
		)
	fi
	# FIXME hack around the fact we can't exclude subdir
	(cd ${POT_DIR}
	for pdir in $OTHER_EXCLUDED_DIRS
	do
		git checkout $pdir
	done
	)
	pot_dir=$(basename ${POT_DIR})
	# FIXME need to be selective based on product dirs
	revert_unchanged_po_git ${POT_DIR}/.. ${pot_dir}
fi

if [ $opt_vc ]; then
	verbose "Update ${PO_DIR} in case any changes are in version control"
	(cd ${PO_DIR};
	git stash $gitverbosity
	git pull $gitverbosity --rebase
	git checkout $gitverbosity
	git stash pop $gitverbosity || true)
fi

verbose "Translations - build Mozilla files in ${L10N_DIR}"
for lang in ${LANGS}
do
	if [ "$lang" == "templates" ]; then
		continue
	fi
	log_info "Language: $lang"
	polang=$(get_language_pootle $lang)
	mozlang=$(get_language_upstream $lang)
	verbose "Migrate - update PO files to new POT files"
	tmp_podir=`mktemp -d tmp.XXXXXXXXXX`
	tmp_templatedir=`mktemp -d tmp.XXXXXXXXXX`
	for pdir in ${PRODUCT_DIRS} ${RETIRED_PRODUCT_DIRS}
	do
		if [ -d  ${PO_DIR}/${polang}/$pdir ]; then
			mkdir -p  ${tmp_podir}/${polang}/$pdir
			cp -rp ${PO_DIR}/${polang}/$pdir/* ${tmp_podir}/${polang}/$pdir
			rm $(find  ${PO_DIR}/${polang}/$pdir -type f -name "*.po")
		fi
		if [ -d  ${POT_DIR}/$pdir ]; then
			mkdir -p  ${tmp_templatedir}/$pdir
			cp -rp ${POT_DIR}/$pdir/* ${tmp_templatedir}/$pdir
		fi
	done
	pomigrate2 --use-compendium --pot2po $pomigrate2verbosity ${tmp_podir}/${polang} ${PO_DIR}/${polang} ${tmp_templatedir}
	rm -r ${tmp_podir} ${tmp_templatedir}

	(cd ${PO_DIR}
	if [ $USECPO -eq 0 ]; then
		(cd ${polang}
		clean_po ${PRODUCT_DIRS}
		)
	fi

	revert_unchanged_po_git ${PO_DIR} ${polang}
	vc_addremove_git ${PO_DIR} ${polang}

	verbose "Pre-po2moz hacks"
	mozlang_product_dirs=
	for dir in ${PRODUCT_DIRS}
	do
		mozlang_product_dirs="${mozlang_product_dirs} $mozlang/$dir"
	done
	for product_dir in ${mozlang_product_dirs}
	do
		[ -d ${L10N_DIR}/${product_dir} ] && find ${L10N_DIR}/${product_dir} \( -name '*.dtd' -o -name '*.properties' \) -exec rm -f {} \;
	done

	verbose "po2moz - Create Mozilla l10n layout from migrated PO files."
	#for exclude in $RETIRED_PRODUCT_DIRS $OTHER_EXCLUDED_DIRS
	#do
	#	excludes="$excludes --exclude=$exclude"
	#done
	po2moz --removeuntranslated --progress=$progress --errorlevel=$errorlevel --exclude=".git" --exclude=".hg" --exclude=".hgtags" --exclude="obsolete" --exclude="*~" $excludes \
		-t ${L10N_ENUS} -i ${PO_DIR}/${polang} -o ${L10N_DIR}/${mozlang}

	if [ $opt_copyfiles ]; then
		verbose "Copy files not handled by moz2po/po2moz"
		if [ $MOZ_PRODUCT == "browser" ]; then
			copyfileifmissing toolkit/chrome/formautofill/requestAutocomplete.dtd ${mozlang}
			copyfileifmissing toolkit/chrome/mozapps/help/welcome.xhtml ${mozlang}
			copyfileifmissing toolkit/chrome/mozapps/help/help-toc.rdf ${mozlang}
			copyfileifmissing browser/firefox-l10n.js ${mozlang}
			copyfileifmissing browser/profile/chrome/userChrome-example.css ${mozlang}
			copyfileifmissing browser/profile/chrome/userContent-example.css ${mozlang}
			copyfileifmissing toolkit/chrome/global/intl.css ${mozlang}
			# This one needs special approval but we need it to pass and compile
			copyfileifmissing browser/searchplugins/list.txt ${mozlang}
		fi
		if [ $MOZ_PRODUCT == "mobile" ]; then
			copyfileifmissing mobile/android/chrome/notification.dtd ${mozlang}
		fi
	fi

	# Revert some files that need careful human review or authorisation
	if [ -d ${L10N_DIR}/${mozlang}/.hg ]; then
		(cd ${L10N_DIR}/${mozlang}
		hg revert $hgverbosity --no-backup \
			browser/chrome/browser-region/region.properties \
			browser/searchplugins/list.txt \
			mobile/chrome/region.properties \
			mail/chrome/messenger-region/region.properties \
                        suite/chrome/common/region.properties \
                        suite/chrome/browser/region.properties \
                        suite/chrome/mailnews/region.properties
		)
	fi

	## CREATE XPI LANGPACK
	if [ "$opt_build_xpi" != "no" ]; then
		if [ "$opt_build_xpi" -o "$(should_build $lang xpi)" ]; then
			mkdir -p ${LANGPACK_DIR}/$project/$lang
			verbose "Language Pack - create an XPI"
			copyfileifmissing browser/chrome/browser-region/region.properties ${mozlang}
			copyfileifmissing browser/searchplugins/list.txt ${mozlang}
	                po2moz --progress=$progress --errorlevel=$errorlevel -t ${L10N_ENUS}/browser/profile/bookmarks.inc -i ${PO_DIR}/${polang}/browser/profile/bookmarks.inc.po -o ${L10N_DIR}/${mozlang}/browser/profile/bookmarks.inc
			buildxpi.py -d -L ${L10N_DIR} -s ${MOZCENTRAL_DIR} -o ${LANGPACK_DIR}/$project/$lang --soft-max-version ${mozlang} > ${LANGPACK_DIR}/$project/$lang/langpack-build.log 2>&1
			hg revert  $hgverbosity --no-backup \
				browser/chrome/browser-region/region.properties \
				browser/searchplugins/list.txt 
		fi
	fi

	# COMPARE LOCALES
	if [ $opt_compare_locales ]; then
		verbose "Compare-Locales - to find errors"
		if [ -f ${MOZCENTRAL_DIR}/${MOZ_PRODUCT}/locales/l10n.ini ]; then
			compare-locales --ignore-missing ${MOZCENTRAL_DIR}/${MOZ_PRODUCT}/locales/l10n.ini ${L10N_DIR} $mozlang
		else
			echo "Can't run compare-locales without ${MOZCENTRAL_DIR} checkout"
		fi
	fi

	# Make a tarball
	if [ "$opt_tarball" != "no" ]; then
		if [ "$opt_tarball" -o "$(should_build $lang tarball)" ]; then
			log_info "Creating tarball of target format"
			mkdir -p ${TARBALL_DIR}
			# Name will be e.g.: af-21.0a2-20130213T1234-xxxxxxx.tar.bz2
			# There is no mobile/config/version.txt so keep it pointing to browser
			version=$(cat ${MOZCENTRAL_DIR}/browser/config/version.txt)
			build_date=$(date +%Y%m%dT%H%M)
			vc_hash=$(get_hash ${PO_DIR}/${polang})
			tarball_name=${mozlang}-$version-$build_date-$vc_hash.tar.bz2
			(cd ${L10N_DIR}
			tar c${tar_verbosity}jf ${TARBALL_DIR}/$tarball_name ${mozlang_product_dirs})
		fi
	fi
	)

done
