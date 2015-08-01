#! /usr/bin/env guile
!#
;
; Atomspace deduplication repair script
;
; Due to bugs, the SQL backend can end up with multiple copies of
; atoms. This script will find them, merge them, and sum the counts
; on the associated count truth values.  Its up to you to recompute
; anything else.

(use-modules (dbi dbi))


(define my-connect 
       (dbi-open "postgresql" "linas:asdf:en_pairs:tcp:localhost:5432"))


(display my-connect) (newline)

