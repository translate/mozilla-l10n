project=lightning
instance=mozilla
user=pootlesync
server=mozilla.locamotion.org
local_copy=$base_dir/.pootle_tmp
phaselist=
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=0
precommand=". /var/www/sites/$instance/env/bin/activate;"
opt_verbose=0

# FIXME we should build this from the get_moz_enUS script
PRODUCT_DIRS="calendar" # Directories in language repositories to clear before running po2moz
# Directories in language repositories to clear before running po2moz
RETIRED_PRODUCT_DIRS=""

OTHER_EXCLUDED_DIRS="browser dom netwerk security services/sync toolkit webapprt mobile embedding chat editor/ui mail other-licenses/branding/thunderbird"

MOZ_PRODUCT=calendar

MOZ_REPO=comm-aurora
L10N_VER=l10n
