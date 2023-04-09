import json
import os
from collections import Counter, defaultdict
from itertools import combinations, product

import numpy as np
import pandas as pd
from tqdm import tqdm

df = pd.read_csv("data/preprocessed/colex_pron_geo_dedup.csv")
folder = "data/phon/phon_sim_concepts"


def load_concept(wordlist):
    wordlistpath = f"data/wordlists/{wordlist}.txt"

    with open(wordlistpath) as f:
        return [x.replace("\n", '') for x in f.readlines()]


def get_lang2lang_by_phon(concepts):
    lang2lang_dict = defaultdict(int)
    lang2lang_concept = defaultdict(int)
    for concept in tqdm(concepts):
        filepath = os.path.join(folder, f"{concept}.csv")
        if os.path.exists(filepath):

            df_concept_phon = pd.read_csv(filepath, index_col="row_1").drop(labels="row_0",
                                                                                                          axis=1)
            df_concept_1 = df[df["C1"] == concept].drop_duplicates(subset=["C1", "SENSE_LEMMA", "LANG_PRON"])
            df_concept_2 = df[df["C2"] == concept].drop_duplicates(subset=["C2", "SENSE_LEMMA", "LANG_PRON"])
            df_concept = pd.concat([df_concept_1, df_concept_2], axis=0)
            langs = list(set(df_concept["LANG_PRON"].tolist()))

            for t1, t2 in combinations(langs, 2):
                l = "~".join(sorted([t1, t2]))

                df_knot_t1 = df_concept[df_concept["LANG_PRON"] == t1]
                df_knot_t2 = df_concept[df_concept["LANG_PRON"] == t2]

                for p1, p2 in product(df_knot_t1["PRON"].tolist(), df_knot_t2["PRON"].tolist()):
                    p1_p2_sim = df_concept_phon.at[p1, p2]

                    # if "phon_sim" not in lang2lang_dict[l]:
                    #     lang2lang_dict[l]["phon_sim"]= defaultdic
                    # else:
                    lang2lang_dict[l] += p1_p2_sim
                    lang2lang_concept[l] += 1
        else:
            print(f"{concept} file doesn't exist! ")

    return lang2lang_dict, lang2lang_concept


def main(wordlist=None):
    if wordlist is not None:
        concepts = load_concept(wordlist)
    else:
        with open("data/wordlists/concepts.json") as f:
            concepts = json.load(f)

    lang2lang_dict, lang2lang_concept = get_lang2lang_by_phon(concepts)
    df_phon = pd.DataFrame.from_dict(lang2lang_dict, orient="index")
    df_nr = pd.DataFrame.from_dict(lang2lang_concept, orient="index")
    df_nr.columns = ["NR_Concept"]
    df_phon.columns = ["Phon_sim"]
    df_merge = df_phon.merge(df_nr, left_on=df_phon.index, right_on=df_nr.index)

    df_merge["source"] = df_merge["key_0"].str.split("~", expand=True)[0]
    df_merge["target"] = df_merge["key_0"].str.split("~", expand=True)[1]
    df_merge = df_merge[["source", "target", "Phon_sim", "NR_Concept"]]

    if wordlist is not None:
        df_merge.to_csv(f"data/phon/lang2lang_phon_{wordlist}.csv", index=False)
    else:
        df_merge.to_csv(f"data/phon/lang2lang_phon.csv", index=False)


if __name__ == '__main__':
    import plac

    plac.call(main)
