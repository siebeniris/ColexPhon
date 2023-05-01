import pandas as pd
from sklearn.utils import shuffle
from sklearn.model_selection import train_test_split
import os

import warnings

warnings.filterwarnings('ignore')

from torch.nn.utils.rnn import pad_sequence
import torch
from torch.utils.data import DataLoader

from pandarallel import pandarallel
pandarallel.initialize(progress_bar=True)


import panphon
ft = panphon.FeatureTable()


def split_data(aff="conc",  modelname="regression", lang=None, output_folder="output/"):
    features = ["syl", "son", "cons", "cont", "delrel", "lat", "nas", "strid", "voi", "sg", "cg", "ant",
                "cor", "distr", "lab", "hi", "lo", "back", "round", "velaric", "tense", "long", "hitone", "hireg"]
    y_col = aff

    if os.path.exists(os.path.join(output_folder, "dev.csv")):
        print(f"training files exist, y_col {y_col}")
        df_dev = pd.read_csv(os.path.join(output_folder, "dev.csv"))
        df_train = pd.read_csv(os.path.join(output_folder, "train.csv"))
        df_test = pd.read_csv(os.path.join(output_folder, "test.csv"))

        df_train["features"] = df_train["PRON"].parallel_apply(
            lambda x: torch.tensor(torch.from_numpy(ft.word_array(features, x)),
                                   dtype=torch.float))

        df_dev["features"] = df_dev["PRON"].parallel_apply(
            lambda x: torch.tensor(torch.from_numpy(ft.word_array(features, x)),
                                   dtype=torch.float))

        df_test["features"] = df_test["PRON"].parallel_apply(
            lambda x: torch.tensor(torch.from_numpy(ft.word_array(features, x)),
                                   dtype=torch.float))
        labels = list(set(pd.concat([df_dev, df_train, df_test])[y_col].tolist()))

        X_train = pad_sequence(df_train["features"].tolist(), batch_first=True)
        X_dev = pad_sequence(df_dev["features"].tolist(), batch_first=True)
        X_test = pad_sequence(df_test["features"].tolist(), batch_first=True)


        if modelname=="regression":
            y_train = torch.tensor(torch.from_numpy(df_train[y_col].to_numpy()), dtype=torch.float)
            y_dev = torch.tensor(torch.from_numpy(df_dev[y_col].to_numpy()), dtype=torch.float)
            y_test = torch.tensor(torch.from_numpy(df_test[y_col].to_numpy()), dtype=torch.float)
        else:
            y_train = torch.tensor(torch.from_numpy(df_train[y_col].to_numpy()), dtype=torch.long)
            y_dev = torch.tensor(torch.from_numpy(df_dev[y_col].to_numpy()), dtype=torch.long)
            y_test = torch.tensor(torch.from_numpy(df_test[y_col].to_numpy()), dtype=torch.long)

        print(f"Train {len(X_train)}, Dev {len(X_dev)}, Test {len(X_test)}.")


        return X_train, X_dev, X_test, y_train, y_dev, y_test, len(labels)


    else:
        print(f"training files not exist, y_col {y_col}")
        # df = pd.read_csv("data/aff+conc/phone_aff_conc_classes.csv")
        df = pd.read_csv("data/aff+conc/colex_aff_conc_dist_pron.csv")

        if lang !=None:
            df = df[df["LANG_PRON"]==lang]

        df = df[["LANG_PRON", "PRON", y_col]].dropna(subset=["PRON", y_col]).drop_duplicates(subset=["PRON"])
        m_labels = len(df[y_col].value_counts().to_dict())
        # sample by the lowest number of samples by the y_col
        # df = df.groupby(y_col).sample(df.groupby(y_col).size().min())
        print(df.value_counts())

        df = shuffle(df, random_state=42)
        # convert features into
        # df["features"] = df["PRON"].parallel_apply(
        #     lambda x: torch.tensor(torch.from_numpy(ft.word_array(features, x)),
        #                            dtype=torch.float))

        df["features"] = df["PRON"].parallel_apply(
            lambda x: torch.tensor(torch.from_numpy(ft.word_array(features, x)),
                                   dtype=torch.long))

        df["LEN"] = df["features"].apply(lambda x: x.shape[0])
        df = df[df["LEN"] <= 25]

        print(f"the size of the data {len(df)}")
        X_train, X_dev_test, y_train, y_dev_test = train_test_split(df["features"], df[y_col], test_size=0.2)
        X_dev, X_test, y_dev, y_test = train_test_split(X_dev_test, y_dev_test, test_size=0.5)

        df_train = df.loc[X_train.index][["LANG_PRON", "PRON", y_col]]
        df_dev = df.loc[X_dev.index][["LANG_PRON", "PRON", y_col]]
        df_test = df.loc[X_test.index][["LANG_PRON", "PRON", y_col]]
        print(f"saving the datasets ..")

        df_train.to_csv(os.path.join(output_folder, "train.csv"))
        df_dev.to_csv(os.path.join(output_folder, "dev.csv"))
        df_test.to_csv(os.path.join(output_folder, "test.csv"))

        X_train = pad_sequence(X_train.tolist(), batch_first=True)
        X_dev = pad_sequence(X_dev.tolist(), batch_first=True)
        X_test = pad_sequence(X_test.tolist(), batch_first=True)


        if modelname=="regression":
            y_train = torch.tensor(torch.from_numpy(y_train.to_numpy()), dtype=torch.float)
            y_dev = torch.tensor(torch.from_numpy(y_dev.to_numpy()), dtype=torch.float)
            y_test = torch.tensor(torch.from_numpy(y_test.to_numpy()), dtype=torch.float)
        else:
            y_train = torch.tensor(torch.from_numpy(y_train.to_numpy()), dtype=torch.long)
            y_dev = torch.tensor(torch.from_numpy(y_dev.to_numpy()), dtype=torch.long)
            y_test = torch.tensor(torch.from_numpy(y_test.to_numpy()), dtype=torch.long)

        print(f"Train {len(X_train)}, Dev {len(X_dev)}, Test {len(X_test)}.")

        return X_train, X_dev, X_test, y_train, y_dev, y_test, m_labels


def dataloader_x_y(X, y, batch_size):
    X_loader = DataLoader(X, batch_size=batch_size)
    y_loader = DataLoader(y, batch_size=batch_size)
    return X_loader, y_loader


def get_loaders(aff="conc", modelname="regression", lang=None, batch_size=32, output_dir="output/"):
    X_train, X_dev, X_test, y_train, y_dev, y_test, m_labels = split_data(aff, modelname, lang, output_folder=output_dir)
    print("train data")

    print(X_train.shape)
    print(y_train.shape)
    print("dev data")
    print(X_dev.shape)
    print(y_dev.shape)
    print("test data")
    print(X_test.shape)
    print(y_test.shape)

    X_train_loader, y_train_loader = dataloader_x_y(X_train, y_train, batch_size)
    X_dev_loader, y_dev_loader = dataloader_x_y(X_dev, y_dev, batch_size)
    X_test_loader, y_test_loader = dataloader_x_y(X_test, y_test, batch_size)

    return X_train_loader, y_train_loader, X_dev_loader, y_dev_loader, X_test_loader, y_test_loader, m_labels


if __name__ == '__main__':
    get_loaders("conc")
