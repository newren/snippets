#!/bin/bash

# Purpose:
#   This script demonstrates how bash does not read an entire file up-front
#   before executing it, so modifying the script it is running on the fly
#   can result in bizarre behavior.  (demonstrate_evil.sh is not modified
#   during run, instead a separate innocuous_script.sh that it writes is.)
#
#   The foo.* scripts in this directory are simpler self-modifying versions
#   that work for each of bash, tcsh, and zsh.
# Safety:
#   This script (and the subscript it writes/executes) is safe to run,
#   UNLESS you have a command named 'evilcommand' somewhere in your $PATH.
# Output:
#   Among other things, the sub-script run by this script will output
#     + evilcommand bla bla
#     ./innocuous_script.sh: line 14: evilcommand: command not found
#   which shows it was executing commented-out code.
# Why it "works":
#   1. Bash reads the script file in chunks
#   2. At various times (I believe after executing external commands or
#      waiting for user input), it does an lseek() to the appropriate
#      location within the file
#   3. bash redirection (and many other basic programs like cp or even
#      editors) do not change a file's inode number when modifying or
#      rewriting it, so the filehandle bash has remains valid.
# How to prevent:
#   1. Have the shell script which you are worried about being
#      modified while running delete itself as its first step.  Then
#      if anyone tries to write a file where the script was, they'll
#      certainly get a new inode number, and the bash process will
#      continue reading from the old deleted (by not yet flushed by
#      the OS) file.
#   1b. You could have the script copy itself to somewhere else, then
#      have the script delete itself, then have it move the copy back
#      to the original location.
#   2. Copy the script somewhere temporary and unique (and preferably
#      unwritable); execute that copy instead.
#   3. Mark the script as immutable (chattr +i).  Only un-mark it as
#      immutable after it is done running.
#   4. Enclose your whole shell script in curly braces, and putting
#      an exit statement at the end, forcing bash to read the whole
#      thing in at once.  e.g.:
#        #/bin/bash
#
#        {
#          ...all your shell commands here...
#          exit $EXIT
#        }
# What else is affected:
#   tcsh and zsh are both affected; but these shells reads up to 4096 bytes
#     at a time and won't re-read that portion
#   zsh is affected, with same caveats as tcsh
#   python, perl, ruby, etc. are unaffected; they do an upfront compile and
#     then run the compiled version

VERBOSE=
#VERBOSE=true

cat >innocuous_script.sh <<\EOF
#!/bin/bash

echo Do some stuff
echo "Inode number of $0 : `stat --format=%i $0`"
time_to_cleanup=0
if [ "$time_to_cleanup" -eq 1 ]; then
  # WARNING: You might think we could just run: evilcommand bla bla
  # right here, but DONT do that.  It'd be really bad.
  echo "Inode number of $0 : `stat --format=%i $0`"
  echo safecommand
  exit 0
fi
sleep 3
echo "All done"  # Note that this is the REAL line 14, and is never executed
EOF

chmod u+x innocuous_script.sh
if test -n "$VERBOSE"; then
  echo "******************************************************"
  echo "Output from running innocuous_script.sh before sleep"
  echo "******************************************************"
fi
bash -x ./innocuous_script.sh &
sleep 1
if test -n "$VERBOSE"; then
  echo "******************************************************"
  echo "innocuous_script.sh when it started running"
  echo "******************************************************"
  cat innocuous_script.sh
fi

# 166 characters from '\n' after sleep back to 'evilcommand'
string_with_166_characters=" # $(printf '=%.s' {1..163})"
# We cannot use sed -i here, because that will write to a temporary
# file and rename it over innocuous_script.sh, meaning it'll point
# to a new inode, but the running innocuous_script.sh bash process
# will still be reading from the old inode.  Instead save the
# contents of the modification to a tmpfile, and do not rename the
# tmpfile but cat its contents over innocuous_script.sh.
tmpfile=$(mktemp)
sed "s/stuff/stuff${string_with_166_characters}/" innocuous_script.sh >$tmpfile
#rm innocuous_script.sh
cat $tmpfile >innocuous_script.sh
rm $tmpfile

if test -n "$VERBOSE"; then
  echo "******************************************************"
  echo "innocuous_script.sh after modifiction during mid-run"
  echo "******************************************************"
  cat innocuous_script.sh

  echo "******************************************************"
  echo "Output from running innocuous_script.sh after sleep"
  echo "******************************************************"
fi
wait
rm innocuous_script.sh
