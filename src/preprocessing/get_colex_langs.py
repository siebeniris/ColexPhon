import os
import json

import pandas as pd


def get_synsets_langs(inputfolder="~/LangSim/data/linguistic_features/langdfs",
                      outputfolder="data/preprocessed/synsets"):
    with open("data/preprocessed/EN_synsets.json") as f:
        synsets = json.load(f)

    for file in os.listdir(inputfolder):
        filepath = os.path.join(inputfolder, file)
        writepath = os.path.join(outputfolder, file)

        print(f"processing file {filepath}")

        df = pd.read_csv(filepath)
        df[["SYN1", "SYN2"]] = df["COLEX"].str.split("_", expand=True)
        print(f"len df {len(df)}")

        df_syn = df[(df["SYN1"].isin(synsets)) | (df["SYN2"].isin(synsets))]
        print(f"len df syn {len(df_syn)}")

        df_syn.to_csv(writepath, index=False)


if __name__ == '__main__':
    import plac

    plac.call(get_synsets_langs)
