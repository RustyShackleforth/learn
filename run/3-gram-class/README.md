
Agglomerative-clustering management scripts
===========================================

The scripts here are used to automate the ingestion of plain-text
UTF-8 files into the third stage of the language learning pipeline.
This stage clusters words into grammatical categories. It assumes
that the second processing step has been completed, and that a
database is available with a large number of disjunct counts,
together with the marginals for them.

You will typically want to make copies of these, and tailor them to
your specific needs and procedures. In particular, many of these
files require database credentials to be set; the exact credentials
to use will depend on which copy of which database you are using.
You WILL be copying around a lot of databases!

A quick overview:

* `foo`