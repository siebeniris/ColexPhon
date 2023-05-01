import torch
import warnings

warnings.filterwarnings("ignore")

import torch.nn as nn


class IPAClassifer(nn.ModuleList):

    def __init__(self, m_labels, feature_size=24, hidden_dim=50, lstm_layers=1):
        super(IPAClassifer, self).__init__()

        self.hidden_dim = hidden_dim
        self.LSTM_layers = lstm_layers
        # self.input_size = input_size  # ipa features, 25, the length of phonemes
        self.feature_size = feature_size  # 24

        self.dropout = nn.Dropout(0.5)
        self.lstm = nn.LSTM(input_size=self.feature_size, hidden_size=self.hidden_dim, num_layers=self.LSTM_layers,
                            batch_first=True)
        self.fc1 = nn.Linear(in_features=self.hidden_dim, out_features=10)
        self.fc2 = nn.Linear(10, m_labels)

    def forward(self, x):
        h = torch.zeros((self.LSTM_layers, x.size(0), self.hidden_dim))
        c = torch.zeros((self.LSTM_layers, x.size(0), self.hidden_dim))

        torch.nn.init.xavier_normal_(h)
        torch.nn.init.xavier_normal_(c)

        out, (_, _) = self.lstm(x, (h, c))
        out = self.dropout(out)
        out = torch.relu_(self.fc1(out[:, -1, :]))
        out = self.dropout(out)
        out = self.fc2(out)

        return out



class IPALinear(nn.ModuleList):

    def __init__(self, m_labels, feature_size=24, hidden_dim=50, lstm_layers=1):
        super(IPALinear, self).__init__()

        self.hidden_dim = hidden_dim
        self.feature_size = feature_size  # 24

        self.dropout = nn.Dropout(0.5)

        self.fc1 = nn.Linear(in_features=self.feature_size, out_features=hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, m_labels)

    def forward(self, x):

        out = self.dropout(x)
        out = torch.relu_(self.fc1(out[:, -1, :]))
        out = self.dropout(out)
        out = self.fc2(out)

        return out

class IPARegression(nn.ModuleList):

    def __init__(self, feature_size=24, hidden_dim=50, lstm_layers=1):
        super(IPARegression, self).__init__()

        self.hidden_dim = hidden_dim
        self.feature_size = feature_size  # 24

        self.dropout = nn.Dropout(0.5)

        self.fc1 = nn.Linear(in_features=self.feature_size, out_features=hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, 1)

    def forward(self, x):

        out = self.dropout(x)
        out = torch.relu_(self.fc1(out[:, -1, :]))
        out = self.dropout(out)
        out = self.fc2(out)

        return out

class IPARegressionLSTM(nn.ModuleList):

    def __init__(self, feature_size=24, hidden_dim=50, lstm_layers=1):
        super(IPARegressionLSTM, self).__init__()

        self.hidden_dim = hidden_dim
        self.LSTM_layers = lstm_layers
        # self.input_size = input_size  # ipa features, 25, the length of phonemes
        self.feature_size = feature_size  # 24

        self.dropout = nn.Dropout(0.5)
        self.lstm = nn.LSTM(input_size=self.feature_size, hidden_size=self.hidden_dim, num_layers=self.LSTM_layers,
                            batch_first=True)
        self.fc1 = nn.Linear(in_features=self.hidden_dim, out_features=10)
        self.fc2 = nn.Linear(10, 1)

    def forward(self, x):
        h = torch.zeros((self.LSTM_layers, x.size(0), self.hidden_dim))
        c = torch.zeros((self.LSTM_layers, x.size(0), self.hidden_dim))

        torch.nn.init.xavier_normal_(h)
        torch.nn.init.xavier_normal_(c)

        out, (_, _) = self.lstm(x, (h, c))
        out = self.dropout(out)
        out = torch.relu_(self.fc1(out[:, -1, :]))
        out = self.dropout(out)
        out = self.fc2(out)

        return out