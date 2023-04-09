import lingpy as lp
import os
import pandas as pd
from lingpy.align.pairwise import nw_align
from tqdm import tqdm
from pandarallel import pandarallel

pandarallel.initialize(progress_bar=True)

output_dir = "data/preprocessed/phon_sim"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)


def phon_sim(t1, t2):
    t1 = ''.join(t1.split())
    t2 = ''.join(t2.split())
    almt1, almt2, sim = nw_align(t1, t2)
    return sim / len(almt1)



df = pd.read_csv("data/preprocessed/colex_pron_geo_dedup.csv")
print(f"there are {len(df)} entries.")
colex = []
for c1, c2 in zip(df["C1"], df["C2"]):
    comb = sorted([c1, c2])
    colex.append("~".join(comb))

df["COLEX"] = colex
colex_list = list(set(colex))
print(f"there are {len(colex_list)} colex patterns")

for colex_pattern in tqdm(colex_list):
    df_colex = df[df["COLEX"] == colex_pattern]
    if len(df_colex) > 1:
        prons = list(set(df_colex["PRON"].tolist()))
        indices = [x for x in range(len(prons))]
        X = pd.crosstab([indices, prons], prons).parallel_apply(
            lambda col: [phon_sim(col.name, x)
                         for x in col.index.get_level_values(1)])
        X.to_csv(os.path.join(output_dir, f"{colex_pattern}.csv"))

    del df_colex
