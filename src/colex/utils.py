import json
import os
from collections import Counter, defaultdict
from itertools import combinations

import pandas as pd
import numpy as np

def co_occurrence_table(df: pd.DataFrame, by_id: str):
    # by_id: language id column
    # lang2lang occurrence table
    # df["Colex_ID"] = df["Colex_ID"].astype("Int64")

    codf = df[[by_id, "COLEX"]]
    co_dict = defaultdict(int)

    num_of_colexification_ignoring_forms = 0
    for k, group in codf.groupby(["COLEX"]):
        num_of_colexification_ignoring_forms += len(group)
        combs = combinations(group[by_id].tolist(), 2)
        # sort the combins of languages -> no need for undirected flattening.
        for p in combs:
            t1, t2 = p
            if t1 != t2:
                co_dict[tuple(sorted(p))] += 1

    co_dict_ = {k: v for k, v in co_dict.items() if v > 0}

    return co_dict_, num_of_colexification_ignoring_forms


def get_codict(df: pd.DataFrame, by_id: str) -> pd.DataFrame:
    # by_id: column name, iso3code.

    print("len: ", len(df))
    df = df.dropna(subset=[by_id])
    co_dict, num_of_colexification_ignoring_forms = co_occurrence_table(df=df, by_id=by_id)

    print(f"output codict size: {len(co_dict)}")
    print("num_of_colexification_ignoring_forms:", num_of_colexification_ignoring_forms)

    print("generating edgelist...")
    lt1, lt2, lv = [], [], []
    for p, v in co_dict.items():
        lt1.append(p[0])
        lt2.append(p[1])
        lv.append(v)

    edge_df = pd.DataFrame(data={"source": lt1, "target": lt2, "weight": lv})

    # normalize the weight
    df_iso_colex = df.groupby([by_id])["COLEX"].count()
    d = df_iso_colex.to_dict()

    edge_df["source_num_colex"] = edge_df["source"].apply(lambda x: d[x])
    edge_df["target_num_colex"] = edge_df["target"].apply(lambda x: d[x])
    edge_df["normalized_weight"] = edge_df["weight"] / (
            edge_df["source_num_colex"] + edge_df["target_num_colex"])

    return edge_df