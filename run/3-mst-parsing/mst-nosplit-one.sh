#!/bin/bash
#
# mst-nosplit-one.sh <filename> <cogserver-host> <cogserver-port>
#
# Support script for MST processing (disjunct counting) of text files.
# Sentence-split one file, submit it, via perl script, to the cogserver.
# When done, move the file over to the `mst-articles` directory.
#
# Example usage:
#    ./mst-nosplit-one.sh foo.txt localhost 17001
#

# Some versions of netcat require the -N flag, and some versions
# of netcat do not know about the -N flag. This is mega-annoying.
# Hack this to match your netcat.
netcat="nc -N"

# Set up assorted constants needed to run.
filename="$1"
# coghost="localhost"
# cogport=17002
coghost="$2"
cogport=$3

splitdir=mst-articles-staging
subdir=mst-articles
observe="observe-mst"

# Punt if the cogserver has crashed. Use netcat to ping it.
haveping=`echo foo | $netcat $coghost $cogport`
if [[ $? -ne 0 ]] ; then
	exit 1
fi

# Split the filename into two parts
base=`echo $filename | cut -d \/ -f 1`
rest=`echo $filename | cut -d \/ -f 2-20`

echo "MST-Processing file >>>$rest<<<"

# Create directories if missing
mkdir -p $(dirname "$splitdir/$rest")
mkdir -p $(dirname "$subdir/$rest")

# Move article to temp directory, while processing.
cp "$filename" "$splitdir/$rest"

# Submit the split article
cat "$splitdir/$rest" | ../submit-one.pl $coghost $cogport $observe

# Punt if the cogserver has crashed (second test,
# before doing the mv and rm below)
haveping=`echo foo | $netcat $coghost $cogport`
if [[ $? -ne 0 ]] ; then
	exit 1
fi

# Move article to the done-queue
mv "$splitdir/$rest" "$subdir/$rest"
rm "$base/$rest"