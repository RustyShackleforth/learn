;
; gen-dict.scm - Generate a random artificial grammar
;
; The generated dictionary is determined by the parameters in this file.
;
(use-modules (opencog) (opencog nlp fake))

; Number of grammatical classes
(define num-classes 10)

; Number of synonyms in a word-class
(define num-synonyms 1)

; Number of Link Grammar link types (connector types)
(define num-link-types 6)

; Maximum size of disjuncts
(define max-disjunct-size 3)

; Disjuncts per section
(define num-disjuncts 20)

; Output file
(define dict-file "/tmp/4.0.dict")

(define dictgen
	(create-dict-generator
		num-classes
		num-synonyms
		num-link-types
		max-disjunct-size
		num-disjuncts))

(print-LG-flat dict-file (dictgen))