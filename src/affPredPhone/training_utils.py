import os
import json

import numpy as np
import torch
from torch import nn
from itertools import chain
from tqdm import tqdm
from sklearn.metrics import classification_report, accuracy_score
from collections import defaultdict

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

torch.manual_seed(42)


def evaluate_model(model, modelname, data, labels, mode="dev"):
    model.eval()
    if modelname == "regression":
        creterion = nn.MSELoss()
    else:
        creterion = nn.CrossEntropyLoss()

    gold = []
    pred = []
    losses = []

    with torch.no_grad():
        for input, label in zip(data, labels):
            output = model(input)

            if modelname != "regression":
                label = label.type(torch.LongTensor)

            if mode == "dev":
                loss = creterion(output, label)
                losses.append(loss.detach().numpy())

            if modelname != "regression":
                output = np.argmax(output.detach().numpy(), axis=1)

            pred.append(output.tolist())
            label = label.detach().numpy()
            gold.append(label.tolist())

    gold_ = list(chain.from_iterable(gold))
    pred_ = list(chain.from_iterable(pred))

    if modelname != "regression":
        report = classification_report(gold_, pred_, output_dict=True)
        # acc = accuracy_score(gold, pred)
        acc = accuracy_score(gold_, pred_)
        if mode == "dev":
            return acc, report, np.average(losses)
        else:
            return acc, report, None
    else:
        return None, None, np.average(losses)


def train_model(model, modelname, optimizer,
                outputfolder,
                train_data, train_label,
                dev_data, dev_label,
                test_data, test_label,
                max_epochs=20):
    model.train()
    if modelname == "regression":
        criterion = nn.MSELoss()
    else:
        criterion = nn.CrossEntropyLoss()

    best_acc = [0]
    mse = np.inf
    loss_dict = {"train": [], "dev": [], "test": dict()}
    for epoch in range(max_epochs):
        print(f"epoch {epoch}")
        gold = []
        pred = []
        losses = []

        for X_train, y_train in tqdm(zip(train_data, train_label)):
            output = model(X_train)
            if modelname != "regression":
                y_train = y_train.type(torch.LongTensor)
            # print(output)
            # print(y_train)

            loss = criterion(output, y_train)

            loss.backward()
            optimizer.step()

            output = output.detach().numpy()
            loss = loss.detach().numpy()

            gold.append(y_train.detach().numpy().tolist())
            if modelname != "regression":
                output = np.argmax(output, axis=1)  # get the labels for output

            pred.append(output.tolist())
            losses.append(loss)

        gold_ = list(chain.from_iterable(gold))
        pred_ = list(chain.from_iterable(pred))

        if modelname == "regression":
            train_loss = np.average(losses)
            loss_dict["train"].append(str(train_loss))

            print(f"train loss {train_loss}")
            _, _, dev_loss = evaluate_model(model, modelname, dev_data, dev_label, "dev")
            dev_loss = float(dev_loss)
            loss_dict["dev"].append(str(dev_loss))
            if dev_loss < mse:
                mse = dev_loss
                print(f"dev mse {mse}")
                _, _, test_loss = evaluate_model(model, modelname, test_data, test_label, "dev")

                result = {
                    "train": str(train_loss),
                    "dev": str(dev_loss),
                    "test": str(test_loss)
                }
                loss_dict["test"][epoch] = str(test_loss)
                outputfile = os.path.join(outputfolder, f"result_epoch_{epoch}.json")
                with open(outputfile, "w") as f:
                    json.dump(result, f)

                torch.save(model.state_dict(), os.path.join(outputfolder, f"model_{epoch}.pt"))



        else:
            train_report = classification_report(gold_, pred_, output_dict=True)
            train_loss = np.average(losses)
            print(f"train loss {train_loss}")
            loss_dict["train"].append(str(train_loss))

            dev_acc, dev_report, dev_loss = evaluate_model(model, modelname, dev_data, dev_label, "dev")
            loss_dict["dev"].append(str(dev_loss))

            if dev_acc > np.max(best_acc):
                print(f"epoch {epoch}, {dev_acc}")
                best_acc.append(dev_acc)
                test_acc, test_report, _ = evaluate_model(model, modelname, test_data, test_label, "test")

                result = {
                    "train": {
                        "report": train_report,
                        "loss": str(train_loss)
                    },
                    "dev": {
                        "report": dev_report,
                        "loss": str(dev_loss)
                    },
                    "test": {
                        "report": test_report,

                    }
                }

                outputfile = os.path.join(outputfolder, f"result_epoch_{epoch}.json")
                with open(outputfile, "w") as f:
                    json.dump(result, f)
                torch.save(model.state_dict(), os.path.join(outputfolder, f"model_{epoch}.pt"))

    with open(os.path.join(outputfolder, "lossdict.json"), "w") as f:
        json.dump(loss_dict, f)
