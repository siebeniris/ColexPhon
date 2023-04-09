import os
import pandas as pd
from Levenshtein import ratio
from tqdm import tqdm
from pandarallel import pandarallel

pandarallel.initialize(progress_bar=True)

df = pd.read_csv("data/preprocessed/colex_pron_geo_dedup.csv")
print(f"there are {len(df)} entries.")

concepts = list(set(df["C1"].tolist() + df["C2"].tolist()))
print(f"there are {len(concepts)} concepts")

output_dir = "data/phon/phon_sim_concepts"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

def levenshtein_sim(t1, t2):
    return ratio(t1, t2)


# run one hour.
for concept in tqdm(concepts):
    df_concept = df[(df["C1"] == concept) | (df["C2"] == concept)]
    df_concept = df_concept.drop_duplicates(subset=["SENSE_LEMMA", "LANG_PRON", "PRON"])

    if len(df_concept) > 1:
        prons = list(set(df_concept["PRON"].tolist()))
        indices = [x for x in range(len(prons))]
        X = pd.crosstab([indices, prons], prons).parallel_apply(
            lambda col: [levenshtein_sim(col.name, x)
                         for x in col.index.get_level_values(1)])
        X.to_csv(os.path.join(output_dir, f"{concept}.csv"))

    del df_concept
