#!/usr/bin/env awk -v cmd=sh -v goto=last -f 

# Awk Variables
#   cmd   - Which command to output. Current valid values are: sh, bash and vi vim mvim mview 
#   goto  - Which line to jump to in the matched file. Current valid values are:

# Output of Grep command
#   $ grep -RnHsi waldo scripts
#   scripts/find-user.js:3:if ( process.argv.length > 1 && process.argv[2] === 'Waldo' )
#   scripts/find-user.js:4:  console.log("You ARE lookin for Waldo")
#   scripts/find-user.js:6:  console.log("You are NOT lookin for Waldo")
#   scripts/find-user.sh:4:if test -n $1 && [[ $1 == 'Waldo' ]]; then
#   scripts/find-user.sh:5:  echo "You ARE lookin for Waldo"
#   scripts/find-user.sh:7:  echo "You are NOT lookin for Waldo"
#   
# Same grep command, executing grep2vim using defaults
#   $ grep -RnHsi waldo scripts | ./grep2vim.awk
#   :e scripts/find-user.sh|:4|:tabe scripts/find-user.js|:3
#   
# Output the full command to be executed in a sh/bash terminal
#   $ grep -RnHsi waldo scripts | awk -v cmd=sh -f ./grep2vim.awk
#   vim -c ":e scripts/find-user.sh|:4|:tabe scripts/find-user.js|:3"
#   
# Change the goto lines from the first to the lastf
#   $ grep -RnHsi waldo scripts | awk -v cmd=sh -v goto=last -f ./grep2vim.awk
#   vim -c ":e scripts/find-user.sh|:7|:tabe scripts/find-user.js|:6"
# 
# Open the files within vim, instead of just spitting out the commands to do so
#   $ grep -RnHsi waldo scripts | awk -v cmd=vim -f ./grep2vim.awk | xargs -I {} -o vim -c '{}'
#
# TODO:
#   - In the iteration body maybe verifying that NF >= 3 (since anything less would be useless), and skip if not
#   - Make compatible with: vi, vim, mvim, view, mview, rvim, rview
#   - Allow an argument called "vicmd" that will dictate what binary to be used
#   - Add Examples using zgrep against /var/log/accountpolicy.log* to *view* the *first* entry in each file (thus
#     showing login time for each file)
#   - If the line numbers arent included, then just open vim with each file in a separate tab, and no lines specified
#     - This logic can be executed on the first record (maybe of each file?), as opposed to checking if $1 is a file or 
#       a num, or if $2 is a num or a match
#     - Parse the output of getexecuted for the grep values, if any are set (to see if -nH is set)
#   - Logic to verify that the line numbers are in order (If not, store/sort them?)
#   - Any args provided after - should be passed to vim
#   - Ability to whitelist/blacklist filetypes/extensions to open
@load "filefuncs"

function _err ( msg, ret ){
  printf( "ERROR: %s\n", msg ) > "/dev/stderr"
  exit ret
}

function _debug ( msg ){
  #if ( msg && cfg["debug"] == 1 )
    printf( "[DEBUG]: %s\n", msg ) > "/dev/stderr"
}

# awk -v file="grep.sh" 'BEGIN {print file, getline < file < 0 ? "does NOT exist" : "DOES exist"}'
function fileexists ( _file ){
  return stat( _file, fstat ) == 0
}

function help ( ret ){
  printf("HELPING\n")

  if ( ret ){
    abort_code = ret
    exit abort_code
  }
}

function isint ( val ){ 
  return val ~ /^[0-9]+$/
}

function isfloat ( val ){ 
  return val ~ /^[0-9]*\.[0-9]+$/
}

function getexecuted (){
  ("ps -p " PROCINFO["pid"] " -o args=") | getline exec_command
  return exec_command
}

function type_get ( var, k, q, z ) {
  k = CONVFMT
  CONVFMT = "% g"
  split(" " var "\34" var, z, "\34")
  q = sprintf("%d%d%d%d%d", var == 0, var == z[1], var == z[2],
  var "" == +var, sprintf(CONVFMT, var) == sprintf(toupper(CONVFMT), var))
  CONVFMT = k

  if (index("01100 01101 11101", q))
    return "numeric string"

  if (index("00100 00101 00110 00111 10111", q))
    return "string"

  return "number"
}

BEGIN {
  cfg["autoexec"]   = 0
  cfg["debug"]      = 0

  for ( i = 0; i < ARGC; i++ ){
     if ( ARGV[i] == "--debug" ){
        cfg["debug"] = 1
     }
  }

  FS                = ":"
  file_lines[""]    = ""  # List of matching line numbers for each file
  cmds["vim"]       = ""  # Array containing the generated commands
  cols[""]          = ""
}
{
  # Is this the first check? Cache some data
  if ( NR == 1 ){
    # Iterate over the fields and attempt to determine which field contains what data
    for( i = 1; i <= NF; i++ ) { 
      fldtype = type_get($i)
      #_debug("==========")
      _debug("$"i" is value: "$i)
      _debug("$"i" is fldtype: "fldtype)
      _debug("$"i" fileexists: "fileexists( $i ))
      #_debug("stat:"stat($2,fstat))
      #_debug("==========")

      if ( fldtype == "string" ){
        if ( fileexists( $i ) == 0 ){
          # $i is more than likely the matched content
          cols["match"] = i
        }
        else { 
          # $i is the filename
          cols["filename"] = i
        }
      }
      else if ( fldtype == "number" || fldtype == "numeric string" ){
        # $i is more than likely the matched line number
        cols["line"] = i
      }
      else {
        _debug("Unable to determine what the field #"i" contains")
      }
    }

    # If we weren't able to determine what col has the filename, then exit
    if ( ! ( "filename" in cols ) ){
      _err("Unable to determine what column contains the file name")
    }

    _debug("cols[filename]: "cols["filename"])

    if ( "filename" in cols )
      _debug("cols[line]: "cols["line"])

    if ( "match" in cols )
      _debug("cols[match]: "cols["match"])
  }

  if ( fileexists( $cols["filename"] ) == 0 ){
    # Shouldn't ever really get here
    _debug($cols["filename"]" is not a file - skipping")
    next
  }

  # If the matched lines are included in grep, then use it. Otherwise, just default to 1
  gotoline = ( "line" in cols ? $cols["line"] : 1 )

  _debug("Adding filename "$cols["filename"]" to file_lines with the line value "gotoline)

  file_lines[$cols["filename"]] = gotoline

  next
}
END {
  if ( abort_code )
    exit abort_code

  delete file_lines[""]

  # Iterate through each file entry, updating final_cmd as needed
  for ( lno in file_lines ){

    # If this is the first command, then it needs to be different
    # if ( length( cmds["vim"] ) == 0 ) 
    #   cmds["vim"] = sprintf(":e %s|:%s", lno, file_lines[lno] )
    # else 
    #   cmds["vim"] = sprintf("%s|:tabe %s|:%s", cmds["vim"], lno, file_lines[lno] )

    cmds["vim"] = ( ( length( cmds["vim"] ) == 0 ) ?
      sprintf( ":e %s|:%s", lno, file_lines[lno] ) :
      sprintf( "%s|:tabe %s|:%s", cmds["vim"], lno, file_lines[lno] ) )
  }

  cmds["bash"] = cmds["sh"] = sprintf("vim -c \"%s\"", cmds["vim"])
 
  # If a specific command is requested
  if ( cmd != "" ){
    if ( cmds[cmd] == "" ){
      printf("No command found for %s\n", cmd) > "/dev/stderr"
      exit 1
    }

    if ( cfg["autoexec"] == 1 ){
      system(cmds[cmd])
      close(cmds[cmd])
    }
    else {
      print cmds[cmd]
    }
    
    exit 0
  }
}