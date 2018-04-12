# Grep2Vim
## Description

- Open up any `grep` results in `vim` editor
- Opens multiple files in separate vim tabs
- Automatically go to the line matched in grep


## Example Usage

```
$ grep -RnHsi waldo scripts
scripts/find-user-2.sh:3:# Check if the first arg is "Waldo"
scripts/find-user-2.sh:4:if test -n $1 && [[ $1 == 'Waldo' ]]; then
scripts/find-user-2.sh:5:  echo "You ARE lookin for Waldo"
scripts/find-user-2.sh:7:  echo "You are NOT lookin for Waldo"
scripts/find-user.js:3:if ( process.argv.length > 1 && process.argv[2] === 'Waldo' )
scripts/find-user.js:4:  console.log("You ARE lookin for Waldo")
scripts/find-user.js:6:  console.log("You are NOT lookin for Waldo")
scripts/find-user.sh:3:# Check if the first arg is "Waldo"
scripts/find-user.sh:4:if test -n $1 && [[ $1 == 'Waldo' ]]; then
scripts/find-user.sh:5:  echo "You ARE lookin for Waldo"
scripts/find-user.sh:7:  echo "You are NOT lookin for Waldo"
$ grep -RnHsi waldo scripts | ./grep2vim.awk
vim -c ":e scripts/find-user-2.sh|:7|:tabe scripts/find-user.sh|:7|:tabe scripts/find-user.js|:6"
$ grep -RnHsi waldo scripts | ./grep2vim.awk | xargs -o vim # Execute above vim command