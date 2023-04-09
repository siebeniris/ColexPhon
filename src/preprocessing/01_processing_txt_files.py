import pandas as pd
import numpy as np
import os
from collections import defaultdict
from itertools import combinations
from tqdm import tqdm
import plac
import json
import multiprocessing
from multiprocessing import Pool




def construct_colex_from_synsets(data_folder, outputfile, statsfile, only_concept):
    # the whole babelnet data is too big to handle
    lemma_dict = defaultdict(list)
    stats_dict = defaultdict(int)
    print(f"only concept => {only_concept}")
    def process_one_file(test_file):
        with open(test_file) as f:
            for line in f.readlines():
                row = line.replace("\n", "").split("\t")
                wordnet_id, typ, lemma, source, lang, pos, is_key_concept = row
                # if only_concept:
                #     if typ == "Concept":  # didn't use for wordnet data.
                #         wn_id = wordnet_id.split("__")[1]
                #         lemma_dict[(lemma.lower(), lang)].append(wn_id)
                #         stats_dict[source] += 1
                # else:

                wn_id = wordnet_id.split("__")[1]
                lemma_dict[(lemma.lower(), lang)].append(wn_id)
                stats_dict[source] += 1

    for file in tqdm(os.listdir(data_folder)):
        if file.endswith(".txt"):
            print(file)
            filepath = os.path.join(data_folder, file)
            process_one_file(filepath)

    counter = 0
    with open(outputfile, "w") as f:
        header = "SENSE_LEMMA\tLANG\tSYNSET1\tSYNSET2\n"
        f.write(header)
        for t, synsets in lemma_dict.items():
            senselemma, lang = t
            synset_l = list(set(synsets))
            if len(synset_l) > 1:
                combs = combinations(synset_l, 2)
                for comb in combs:
                    comb = sorted(comb)
                    line = f"{senselemma}\t{lang}\t{comb[0]}\t{comb[1]}\n"
                    counter += 1
                    print(counter)
                    f.write(line)

    with open(statsfile, "w") as f:
        json.dump(stats_dict, f)


if __name__ == '__main__':
    import plac

    plac.call(construct_colex_from_synsets)
