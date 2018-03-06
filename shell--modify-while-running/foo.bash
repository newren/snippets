#!/bin/bash

# Run like this:
#   cp foo.bash tmp.bash; bash tmp.bash
# and see if it prints "Finished" for the final line as you'd expect.

echo "Inode number of $0 : `stat --format=%i $0`"
num_lines=$((`grep -n Finished $0 | tail -n 1 | /bin/sed -e "s/:.*//"` - 1))
(head -n $num_lines $0; echo "echo Gremlins modified your script") >$0.bak
cp -a $0.bak $0
rm $0.bak
echo "Inode number of $0 : `stat --format=%i $0 `"
sleep 1
echo Finished
