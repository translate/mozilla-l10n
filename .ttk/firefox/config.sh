project=firefox
instance=mozilla
user=pootlesync
server=pootle.locamotion.org
local_copy=$base_dir/.pootle_tmp
phaselist=firefox.phaselist
manage_command="/var/www/sites/$instance/src/manage.py"
manage_py_verbosity=2
precommand=". /var/www/sites/$instance/env/bin/activate;"
opt_verbose=3

# FIXME we should build this from the get_moz_enUS script
PRODUCT_DIRS="browser dom netwerk security services/sync toolkit" # Directories in language repositories to clear before running po2moz
# Directories in language repositories to clear before running po2moz
RETIRED_PRODUCT_DIRS="other-licenses/branding/firefox extensions/reporter"

MOZ_PRODUCT=browser
