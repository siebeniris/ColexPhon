import os
import plac

import torch
import torch.optim as optim

from src.affPred.get_data import get_loaders
from src.affPred.models import IPAClassifer, IPALinear, IPARegression, IPARegressionLSTM
from src.affPred.training_utils import train_model

torch.manual_seed(42)


def run_model(aff="conc", modelname="regression", lang=None, batch_size=64, epochs=20, device="cpu",
              output_folder="output/"):
    if lang is None:
        outputfolder = os.path.join(output_folder, aff)
        if not os.path.exists(outputfolder):
            os.makedirs(outputfolder)
    else:
        outputfolder = os.path.join(output_folder, f"{aff}_{lang}")
        if not os.path.exists(outputfolder):
            os.makedirs(outputfolder)
    print(f"aff {aff} model {modelname}")
    X_train_loader, y_train_loader, X_dev_loader, y_dev_loader, X_test_loader, y_test_loader, m_labels = get_loaders(
        aff, lang=lang,
        batch_size=batch_size,
        output_dir=outputfolder)
    print(f"num labels {m_labels}")

    if modelname == "lstm":

        model = IPAClassifer(m_labels)
    elif modelname == "linear":

        model = IPALinear(m_labels)
    elif modelname == "regression":
        model = IPARegression()
        # model = IPARegressionLSTM()
    else:
        model = IPALinear(m_labels)

    model = model.to(device)

    # X_train_loader = X_train_loader.to(device)
    # y_train_loader = y_train_loader.to(device)
    # X_dev_loader = X_dev_loader.to(device)
    # y_dev_loader = y_dev_loader.to(device)
    # X_test_loader = X_test_loader.to(device)
    # y_test_loader = y_test_loader.to(device)

    optimizer = optim.Adam(model.parameters(), lr=0.0001)

    train_model(model, modelname, optimizer, outputfolder,
                X_train_loader, y_train_loader,
                X_dev_loader, y_dev_loader,
                X_test_loader, y_test_loader,
                max_epochs=epochs)


if __name__ == '__main__':
    plac.call(run_model)
