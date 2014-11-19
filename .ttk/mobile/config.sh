project=mobile
instance=mozilla
user=pootlesync
server=mozilla.locamotion.org
local_copy=$base_dir/.pootle_tmp
phaselist=
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=0
precommand=". /var/www/sites/mozilla/env/bin/activate;"
opt_verbose=0

# FIXME we should build this from the get_moz_enUS script
# Directories in language repositories to clear before running po2moz
PRODUCT_DIRS="mobile"
# Directories in language repositories to clear before running po2moz
RETIRED_PRODUCT_DIRS="embedding"

OTHER_EXCLUDED_DIRS="calendar editor mail thunderbird chat browser dom netwerk security services sync toolkit webapprt"

MOZ_PRODUCT=mobile

MOZ_REPO=mozilla-aurora
MOZ_DIR="mozilla-aurora"
L10N_VER=l10n

alt_src="es fr ru"
