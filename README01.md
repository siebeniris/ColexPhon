# ColexPhon
Colexification and Phonetics


## wikipron
non-empty languages: 164, dedup+entry>10: 105


#### intersection of colex and prons.
`data/preprocessed/colex_pron_langs.csv`

- with (lat, long) geo information
  - `data/preprocessed/colex_pron_geo.csv`

- dedupped:
  - `data/preprocessed/colex_pron_geo_dedup.csv`
  - `data/preprocessed/langs_nr.json`


phonemes vs. concretness

IPA

start with plosive/fricative (binary)

kiki bouba effect concretness

NEXT STEPS:
1. COMPARE ALSO WITH Gast paper, phylogenetic relations (DataStageV)
2. compare different set of lexicons with different previous work
3. make some nice visualizations of colexifications.





## colexifications
- entries: 945382
- lexicalizations 129677, colexification 510198
-  ignoring the lexical form per (colex, lang): 859296
- 6713 pair of languages. 
- 

## phonemes
- concepts intotal: 22348, having more than 1 language: 20176
- `data/phon/lang2lang_phon.csv`




# Analysis


## Colex and Concreteness

- clear support for hypothesis : the conepts closer in concreteness are more probable to colexify 
  - analyze it monolingually and crosslingually
  - linear regression, coefficients.

- related work about conceptual background for colexification



## geo/colex/phonology
- clear support for phonology/geo
  - farther the languages' distances are, further the phonetic similarity
- colex doesn't have this clear-cut support


## languages 
top-family, isocode, etc.
https://glottolog.org/resourcemap.json?rsc=language
