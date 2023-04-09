import json
import os
from collections import Counter, defaultdict

import pandas as pd
import numpy as np
from src.colex.utils import *


def get_colex_df(inputfile, wordlist=None):
    # SENSE_LEMMA   LANGUAGE   SYNSET1  SYNSET2 COLEX
    df = pd.read_csv(inputfile)
    print(f"df {len(df)}")
    colex = df["COLEX"].tolist()
    colex_freq_dict = dict(Counter(colex).most_common())
    lexicalization = len(df.drop_duplicates(subset=["SENSE_LEMMA", "LANG_PRON"]))
    colexifications = len(set(colex))
    print(f"lexicalizations {lexicalization}, colexification {colexifications}")

    # ignore different lexicons colexifing the same pairs of concepts.
    df = df.drop_duplicates(subset=["LANG_PRON", "COLEX"])
    print(f"dedup {len(df)}")

    return df


def generate_lang2lang(inputfile, outputfile):
    df = get_colex_df(inputfile)
    lang2lang_df = get_codict(df, by_id="LANG_PRON")
    lang2lang_df.to_csv(outputfile, index=False)


if __name__ == '__main__':
    import plac

    plac.call(generate_lang2lang)
