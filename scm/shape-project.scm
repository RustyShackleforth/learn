;
; shape-project.scm
;
; Merge connectors based on linea shape merges.
;
; Copyright (c) 2021 Linas Vepstas
;
; ---------------------------------------------------------------------
; OVERVIEW
; --------
; The creation of clusters is done via a "linear" projective merge of
; vectors that encode Sections. See top of `gram-projective.scm` for
; an overview of the general idea of linear projective merging.
;
; Recall that the "germ" of a Section is the first element of the
; section, the "vertex". The rest of the Section is a ConnectorSeq.
; A "vector" is a single germ, and all of the Sections on it.
; Linear (projective) merging refers to the idea that, to merge two
; vectors, one need only merge thier germs into a common class
; (cluster). A new vector is created, having that cluster as the germ,
; and including parts of the vectors of the two donor germs. The
; mechanical process of creating the new vector is implemented in
; `gram-projective.scm`.
;
; A problem arises when Sections contain Connectors in which the
; donating germs appear. How should this be handled? There is certainly
; a rich variety of choices, which then easily lead to confusing
; questions. To minimize the confusion, a principle of linearity is
; invoked.  This principle leads to the idea of Shapes and
; CrossSections. These last two are described in `shape-vec.scm`
;
; Thus, the concept of a vector of Sections sitting on a germ is
; extended to a vector of Sections and CrossSections on that germ.
; This is a kind of "direct sum" of the two vectors. The goal is
; to continue to do merging as before, a linear projection of two
; vectors onto a common cluster, making use of the CrossSections to
; provide a suggestion of how germs in Connectors should be merged.
;
; Basic Merging Example
; ---------------------
; Consider the following projective merge, taken from the
; `connector-merge-basic.scm` unit test:
;
;    (e, abc) + (j, abc) -> ({ej}, abc)
;    (e, dgh) + (j, dgh) -> ({ej}, dgh)
;    (e, klm) +  none    -> p * ({ej}, klm) + (1-p) * (e, klm)
;
; In this diagram, (e,abc) is abbreviated notation for
; (Section (Word e) (ConnectorList (Connector a) (Connector b) (Connector c)))
; and so on.
; {ej} is short for (WordClassNode "e j") (a set of two words)
; "p" is the fraction of the count on the original donor section
; that should be moved to the merged vector. Note that this is where
; the "linearily" comes in: counts are additive, and p + (1-p) = 1
; i.e. the total count is preserved; it is only redistributed between
; the vectors.
;
; The above has NO germs in any of the connectors, and so merging the
; corresponding sections is straight-forward.
;
; CrossSection Merging Example
; ----------------------------
; Given the above 5 Sections (3 for "e" and 2 for "j"), they may be
; exploded into 15 CrossSections, 3 each for the 5 total Sections.
;
; For example, (e, abc) explodes to
;
;    [a, <e, vbc>]   and  [b, <e, avc>]  and  [c, <e, abv>]
;
; where [] denotes the CrossSection, and <> denotes the Shape. The "v"
; is the variable node in the Shape (that the germ of the cross-section
; plugs into).
;
; Of the 15 CrossSections, none of them have "e" or "j" as a germ,
; and therefore, none of them contribute to the vectors to be merged.
; However, they all have Shapes whose point is a germ.
;
; Insofar as CrossSections are secondary and are derived from the
; Sections, self-consistency suggests that they should stay consistent
; with the results of the merger of the Sections. Thus, post-merger,
; the number of Sections should reduce to 12 = 3x4, wiht 9 of them
; having {ej} as the point, and 3 more having just {e} as the point.
; Counts should update as well.
;
; The function `merge-crosses` below maintains this correspondence, for
; the simple case.
;
; Connector Merging Example
; -------------------------
; Consider the following projective merge, taken from the
; `connector-merge-full.scm` unit test:
;
;    (e, abc) + (j, abc) -> ({ej}, abc)
;    (e, dgh) + (j, dgh) -> ({ej}, dgh)
;    (e, klm) +  none    -> p * ({ej}, klm) + (1-p) * (e, klm)
;     none    + (j, abe) -> p * ({ej}, abx) + (1-p) * (j, aby)
;     none    + (j, egh) -> p * ({ej}, zgh) + (1-p) * (j, wgh)
;
; Here, the germ "j" has two sections with contain "e" as a connector.
; After merging, it is less than clear as to what x,y,z,w should be.
; There are several possibilities:
;
; 1)   x and  y could both be "e"
; 2)   x and  y could both be {ej}
; 3)   x could be {ej} and y could be just "e"
;
; In addition, although "p" was written as the merge fraction on the
; last two, it is not obviously the correct fraction.
;
; For guidance, lets look at what is happening with the cross-sections.
; The Section (j, abe) has three cross-sections on it:
;
;    [a, <j, vbe>]   and  [b, <j, ave>]  and  [e, <j, abv>]
;
; We are interested only in the last cross-section, as it is the only
; one on the vector for the germ "e". The merge for this looks like:
;
;     none + [e, <j, abv>] -> p * [{ej}, <j, abv>] + (1-p) * [e, <j, abv>]
;
; Given the above post-merge form, we can now reconstruct the
; corresponding post-merge Sections. The are
;
;     [{ej}, <j, abv>]  => (j, ab{ej})
;     [e, <j, abv>]  => (j, abe)
;
; and so this reconstruction recommends:
;
;     none + (j, abe) -> p * (j, ab{ej}) + (1-p) * (j, abe)
;
; Compare to the earlier direct merge of the Sections:
;
;     none + (j, abe) -> p * ({ej}, abe) + (1-p) * (j, abe)
;
; Ugh. Non-commutative. Now what???
;
; Diary entry for "April-May 20201 ...Non-Commutivity, Again... Case B"
; discusses what to do, and why to do it that way. The conclusion is
; that the right answer, here is to create a section
;    p * ({ej}, ab{ej})
; and to zero out the other two.
;
; ---------------------------------------------------------------------

(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog matrix) (opencog persist))

; ---------------------------------------------------------------------

(define (merge-recrosses LLOBJ GLS DONOR FRAC NOISE)
"
  merge-recrosses - merge cross-sections corresponding to GLS and DONOR.

  GLS should be a cluster node (prototypically, a WordClassNode)
  DONOR should be a Section which is being merged into GLS.

  This method keeps the CrossSections in sync with the corresponding
  merged Section (i.e. the Section having GLS as the germ).

  A fraction FRAC of all of the CrossSections on DONOR will be merged
  into the corresponding CrossSections on GLS.  Here, GLS is assumed
  to be the germ of the cluster (prototypically, a WordClassNode),
  while DONOR is assumed to a a Section. The DONOR Section will be
  exploded into it's CrossSections, and a FRAC of the count on the
  donor CrossSections will be transfered to the corresponding crosses
  on GLS. If the count on the CrossSections is less than NOISE, then
  all of the count will be merged.
"
	; Create the matching cross-section, and transfer counts to it.
	; xmr is a CrossSection, with GLS appearing in all places where
	; the germ of DONOR had appeared.
	(define (merge-cross XST)
		(define xmr (LLOBJ 're-cross GLS XST))
		(accumulate-count LLOBJ xmr XST FRAC NOISE)
	)

	; Loop over donating cross-sections.
	(for-each merge-cross (LLOBJ 'get-cross-sections DONOR))
)

(define (rebalance-count LLOBJ SECTION CNT)
"
  rebalance-count LLOBJ SECTION CNT - set count on section and crosses.

  The SECTION is presumed to be some section on which the observation
  count was adjusted (possibly even set to zero.) This function
  enforces 'detailed balance', making sure that the CrossSections
  corresponding to SECTION have the same count.
"
	(set-count SECTION CNT)
	(for-each
		(lambda (XST) (set-count XST CNT))
		(LLOBJ 'get-cross-sections SECTION))
)

; ---------------------------------------------------------------------

(define (flatten-resects LLOBJ GLS XMR RESECT)
"
  flatten-resects - Merge Sections corresponding to CrossSection XMR

  GLS is assumed to be a cluster node.
  XMR is assumed to be a CrossSection.
  RESECT is assumed to be the Section corresponding to XMR

  This replaces the germ of RESECT by GLS. The entire count on XMR
  is transfered to this new section.  All of the CrossSections
  corresponding to the new Section are also created. By 'transfered'
  it is meant that XMR ends with a zero count on it.

  The goal of this routine is to create a single Section (and its
  crosses) that have GLS both as the germ, and in the appropriate
  connector locations.

  Example:
    XMR is (CrossSection 'ej' (Shape j a b var))
    GLS is 'ej'
    Creates (Section 'ej' (ConnectorSeq a b 'ej'))
"

	; Replace the germ of RESECT by GLS.
	(define mgs
		(LLOBJ 'make-pair GLS (LLOBJ 'right-element RESECT)))

	(define cnt (LLOBJ 'get-count XMR))
	(set-count XMR 0)

	; Now create the cross-sections corresponding to `mgs`
	(for-each
		(lambda (xfin) (set-count xfin cnt))
		(LLOBJ 'make-cross-sections mgs))
)

(define (merge-resects LLOBJ GLS W XMR XDON)
"
  merge-resects - Merge Sections corresponding to CrossSection XMR

  XMR is assumed to be a cross-section having GLS as it's germ,
  XDON is assumed to be a cross-section having W as it's germ, and
  counts have already been transfered approprately from XDON to XMR.
  That is, its assumed the node W has been merged into the cluster
  node GLS already.

  This function adjusts counts on the corresponding sections that
  arise from XDON and XMR. If the germ of the Section arising from
  XMR belongs to GLS, then a revised Section is created, having GLS
  as the germ.
"
	(define resect (LLOBJ 'make-section XMR))
	(define germ (LLOBJ 'left-element resect))

	(define mgsf (LLOBJ 'flatten GLS resect))
	(define mgs (if mgsf mgsf resect))

	; This is confusing ... can't we just call accumulate-count?
	; (accumulate-count LLOBJ mgs donor FRAC NOISE)
	; ???
	(if (nil? (cog-link 'MemberLink germ GLS))
		(let ((donor (LLOBJ 'make-section XDON))
				(x-cnt (LLOBJ 'get-count XMR))
				(d-cnt (LLOBJ 'get-count XDON)))

			(if mgsf (rebalance-count LLOBJ resect 0))
			(rebalance-count LLOBJ mgs x-cnt)
			(rebalance-count LLOBJ donor d-cnt)
		)
		(flatten-resects LLOBJ GLS XMR mgs))
)

; ---------------------------------------------------------------------

(define (reshape-merge LLOBJ GLS MRG W DONOR FRAC NOISE)
"
  reshape-merge LLOBJ GLS MRG W DONOR FRAC NOISE

  Merge connectors on the Section/CrossSection MRG.
  This creates a set of 'consistent' Sections/CrossSections such that
  these contain the merged cluster node GLS in the appropriate places
  as germs, points or in connectors. The problem addressed here is that
  the ordinary linear projective merge does correctly create the merged
  Sections/CrossSections with GLS as the germ, but leaves behind a
  mish-mash of the raw unmerged word W to appear in various Shapes (as
  the point) and in various Connectors. These need to be harmonzed so
  that W is replaced by GLS in all the right places, with counts updated
  appropriately.

  When this completes, the resulting Sections/CrossSections are fully
  self-consistent. The inconsistent Sections/CrossSections will have
  thier counts set to zero, and need to be deleted in a subsequent pass.
"
	(define donor-type (cog-type DONOR))

	(when (equal? 'Section donor-type)
		(let ((flat (LLOBJ 'flatten GLS MRG)))
			(if flat
				(begin
					(accumulate-count LLOBJ flat MRG 1.0 NOISE)
					(rebalance-count LLOBJ flat (LLOBJ 'get-count flat)))
				(merge-recrosses LLOBJ GLS DONOR FRAC NOISE)))

		; Always rebalance the donor.
		(rebalance-count LLOBJ MRG (LLOBJ 'get-count MRG))
		(rebalance-count LLOBJ DONOR (LLOBJ 'get-count DONOR))
	)

	(when (equal? 'CrossSection donor-type)
		(merge-resects LLOBJ GLS W MRG DONOR))
)

; ---------------------------------------------------------------

(define (remove-empty-sections LLOBJ ROW)
"
  remove-empty-sections LLOBJ ROW -- scan the ROW for Sections &
  CrossSections and call cog-delete! on those that have an zero count.
  This will also delete the corresponding CrossSections.
"
	(define ns 0)
	(define nx 0)

	; If the count in Section is zero, delete it.
	; Also scan all of it's crosses
	(define (del-sect SEC)
		(for-each (lambda (xst)
			(when (and (cog-atom? xst) (is-zero? (LLOBJ 'get-count xst)))
				(cog-delete! xst)
				(set! nx (+ 1 nx))))
			(LLOBJ 'get-cross-sections SEC))
		(when (is-zero? (LLOBJ 'get-count SEC))
			(cog-delete! SEC)
			(set! ns (+ 1 ns))))

	(define (del-xes XST)
		(define sct (LLOBJ 'get-section XST))
		(when (and (cog-atom? sct) (is-zero? (LLOBJ 'get-count sct)))
			(cog-delete! sct)
			(set! ns (+ 1 ns)))
		(when (is-zero? (LLOBJ 'get-count XST))
			(cog-delete! XST)
			(set! nx (+ 1 nx))))

	; Cleanup after merging.
	(for-each
		(lambda (ITEM)
			(if (cog-atom? ITEM)
				(cond
					((eq? 'Section (cog-type ITEM)) (del-sect ITEM))
					((eq? 'CrossSection (cog-type ITEM)) (del-xes ITEM))
					(else
						(throw 'remove-empty-sections 'assert "Its broken")))
				))
		(LLOBJ 'right-stars ROW))
	; (format #t "Deleted ~A secs, ~A crosses for ~A" ns nx ROW)
)

; ---------------------------------------------------------------------
