import os
import json

import plac
import pandas as pd


def get_prons(lang, lemmas, datafolder="data/phon/wikipron/data/scrape/tsv/"):
    l_dfs = []
    print(f"processing language {lang}")
    for file in os.listdir(datafolder):

        if file.startswith(lang):
            filepath = os.path.join(datafolder, file)
            df = pd.read_csv(filepath, sep='\t', header=None)
            df.columns = ["lemma", "pron"]
            l_dfs.append(df)
    try:
        df_lang = pd.concat(l_dfs)

        if len(df_lang) > 0:
            df_lang = df_lang[df_lang["lemma"].isin(lemmas)].drop_duplicates(subset=["lemma"])
            print(len(df_lang))
            if len(df_lang) > 0:
                return df_lang
            else:
                return None
        else:
            print(f"no data for the language {lang}")
            return None
    except Exception as msg:
        print(f"exception {msg}")


def main():
    with open("data/preprocessed/lemmas_lang.json", ) as f:
        lang_lemmas_dict = json.load(f)
    counter =0
    for lang, lemmas in lang_lemmas_dict.items():
        df_lang = get_prons(lang, lemmas)
        if df_lang is not None:
            df_lang.to_csv(f"data/phon/preprocessed/{lang}.tsv", sep="\t", index=False)
            counter +=1
    print(f"counter {counter}")

if __name__ == '__main__':
    main()
