import os
import json

import pandas as pd


def get_synsets_langs(inputfolder="~/LangSim/data/synsets_bb_lang", outputfolder="data/preprocessed/synsets"):
    with open("data/preprocessed/EN_synsets.json") as f:
        synsets = json.load(f)

    for file in os.listdir(inputfolder):
        filepath = os.path.join(inputfolder, file)
        writepath = os.path.join(outputfolder, file)
        writer = open(writepath, "w+")
        print(f"processing file {filepath}")
        with open(filepath) as f:

            for line in f.readlines():
                t1, t2 = line.replace("\n", "").split("\t")
                if t1 in synsets:
                    writer.write(line)

        writer.close()

if __name__ == '__main__':
    import plac
    plac.call(get_synsets_langs)