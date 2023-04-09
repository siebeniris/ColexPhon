from nltk.metrics import *
import pandas as pd
import plac

bm = BigramAssocMeasures


class MeasureAssociation:
    def __init__(self, filepath, data, N):
        self.filepath = filepath
        self.data = data
        self.N = N

    @classmethod
    def load_data(cls, filepath, N):
        df = pd.read_csv(filepath)
        return cls(filepath, df, N)

    def display(self):
        if len(self.data) > 0:
            print(self.data.head(), self.N)
        else:
            print("empty data")

    def metrics(self, source_lang, target_lang, coocur, source, target, N):
        normalized_weight = coocur/(source+target)
        student_t = bm.student_t(coocur, (target, source), N)
        chi_sq = bm.chi_sq(coocur, (target, source), N)
        likelihood_ratio = bm.likelihood_ratio(coocur, (target, source), N)
        mi_like = bm.mi_like(coocur, (target, source), N)
        pmi = bm.pmi(coocur, (target, source), N)
        phi_sq = bm.phi_sq(coocur, (target, source), N)
        poisson_stirling = bm.poisson_stirling(coocur, (target, source), N)
        jaccard = bm.jaccard(coocur, (target, source), N)
        dice = bm.dice(coocur, (target, source), N)
        # row = (source_lang, target_lang, coocur, source, target, normalized_weight,
               # student_t, chi_sq, likelihood_ratio, mi_like, pmi,
               # phi_sq, poisson_stirling, jaccard, dice)
        row = (source_lang, target_lang, coocur, source, target, normalized_weight,
               pmi)
        return row

    def build_records(self):
        header = ["source", "target", "weight", "target_nr", "source_nr", "normalized_weight",
                  "pmi"]
        rows = []
        for source_lang, target_lang, weight, source_num_colex, target_num_colex in zip(self.data["source"].tolist(),
                                                                                        self.data["target"].tolist(),
                                                                                        self.data["weight"].tolist(),
                                                                                        self.data[
                                                                                            "source_num_colex"].tolist(),
                                                                                        self.data[
                                                                                            "target_num_colex"].tolist()):
            row = self.metrics(source_lang, target_lang, weight, source_num_colex, target_num_colex, self.N)
            rows.append(row)
        # list(set(lst1) | set(lst2))
        cols = list(set(self.data.columns) | set(header))
        print(cols)
        df_records = pd.DataFrame.from_records(rows, columns=header)
        df_concat = pd.concat([df_records, self.data], axis=1)

        # df3 = df1.merge(df2, how='outer')
        # df_merge = self.data.merge(df_records, how="outer")\
        df = df_concat.loc[:, ~df_concat.columns.duplicated()].copy()
        return df


def get_total_number_colexification(file):
    # two entries for one language "goa", different forms but mean the same concept.
    df = pd.read_csv(file, low_memory=False)
    source2nr = dict(zip(df["source"], df["source_num_colex"]))
    target2nr = dict(zip(df["target"], df["target_num_colex"]))
    lang2nr = source2nr | target2nr
    return sum(lang2nr.values())


def main(inputfile, outputfile):
    N = get_total_number_colexification(
        file=inputfile)  # number of total colexificaiton
    print("total number of colexifications: ", N)
    measurer = MeasureAssociation(inputfile, [], N)
    measurer.display()
    measurer = MeasureAssociation.load_data(inputfile, N)
    measurer.display()
    df_records = measurer.build_records()
    df_records.to_csv(outputfile, index=False)


if __name__ == '__main__':
    plac.call(main)