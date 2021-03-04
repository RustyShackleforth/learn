#!/bin/bash
#
# pair-submit.sh
#
# Batch word-pair counting script for fake generated languages.
#
# Loop over all of the corpora files (all the files in $CORPORA_DIR),
# and then (optionally) sentence-split them and submit them for
# word-pair couting. Word-pair counting is done on a properly-configured
# cogserver.
#
# As files are processed, them will be moved from $CORP to the directory
# `submitted` in the current working dir.
#
# ---------

if [ -r ../0-config/0-pipeline.sh ]; then
	. ../0-config/0-pipeline.sh
else
	echo "Cannot find master configuration file!"
	exit -1
fi

if [ -r $PAIR_CONF_FILE ]; then
	. $PAIR_CONF_FILE
else
	echo "Cannot find word-pair counting configuration file!"
	exit -1
fi

if $SENTENCE_SPLIT; then
	time find $CORPORA_DIR -type f \
		-exec ./pair-one.sh $SPLIT_LANG {} $HOSTNAME $PORT $CORPORA_DIR \;
else
	time find $CORPORA_DIR -type f \
		-exec ./pair-nosplit-one.sh {} $HOSTNAME $PORT $CORPORA_DIR \;
fi