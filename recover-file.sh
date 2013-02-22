lang=$1
shift
files=$*

cd ..
for file in $files
do
	moz2po -t l10n/en-US/$file l10n/$lang/$file po/$lang/${file}.po
done
cd po
./cleanup-msgcat.sh $lang
