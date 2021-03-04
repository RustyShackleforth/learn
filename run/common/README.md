
Parse management scripts
========================

The scripts here are used to automate the operation of the
language-learning pipeline. This directory contains scripts shared
by several different steps.

File overview
-------------
Several files common to several of these steps are located in this
directory.  A quick overview:

* `split-sentences.pl`: Split text files into sentences. Accepts
  free-form text, and looks for language-depedeny likely end-of
  sentence locations, so that there is one sentence per line.
  It's language-dependent, in order to not confuse abbreviations
  with end-of-sentence markers.

* `nonbreaking_prefixes` Used by the sentence-splitter to avoid
  breaking on abbreviations.

* `submit-one.pl`: Script to send single sentences to the cogserver.
  Used both for pair-counting, and for MST-parsing.

* `renice.sh`: Make the postgres server run under a nice priorty.

* `rc.local.shutdown`, `rc-local-shutdown.service`, `rc.lxc.shutdown`:
  Shutdown scripts. These are invoked automatically by the system
  during a power outage, or during a normal shutdown. They attempt
  to properly helt the learning pipeline, so as to avoid a scrambled
  database upon reboot.

* `halt-all.sh`: Stop all running LXC containers.

Sentence Splitting
------------------
Raw text needs to be split up into sentences.  Some distant future day,
opencog will do this automatically. For now, we hack it.

Currently, splitting is done with the `split-sentences.pl` perl script
in the this directory.  It was stolen from the `moses-smt` package.
https://github.com/moses-smt/mosesdecoder/tree/master/scripts/share/nonbreaking_prefixes
It splits French, Polish, Lithuanian, and more.  Its LGPL.

You can verify that it works, like so:
```
   cat text-file | ./split-sentences.pl -l en > x
```
Replace `en` by the language of your choice.

Some typical sentence-splitting concerns that the above script seems
to mostly handle correctly:

A question mark or exclamation mark always ends a sentence.  A period
followed by an upper-case letter generally ends a sentence, but there
are a number of exceptions.  For example, if the period is part of an
abbreviated title ("Mr.", "Gen.", ...), it does not end a sentence.
A period following a single capitalized letter is assumed to be a
person's initial, and is not considered the end of a sentence.