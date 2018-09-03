for FILE in "`find . -name "*_*" | grep -v ostools`"; do
shfmt $FILE
#echo "mv -f "$FILE_new" "$FILE""
#mv -f $FILE_new $FILE
done
