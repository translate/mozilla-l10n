project=mobile
instance=mozilla
user=pootlesync
server=pootle.locamotion.org
local_copy=$base_dir/.pootle_tmp
phaselist=
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=2
precommand=". /var/www/sites/mozilla/env/bin/activate;"
opt_verbose=3

# FIXME we should build this from the get_moz_enUS script
# Directories in language repositories to clear before running po2moz
PRODUCT_DIRS="mobile embedding"
# Directories in language repositories to clear before running po2moz
RETIRED_PRODUCT_DIRS=""

MOZ_PRODUCT=mobile
