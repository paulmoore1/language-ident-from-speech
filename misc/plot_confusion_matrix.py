#!/usr/bin/env python3
import argparse, os
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from collections import OrderedDict
from sklearn.metrics import confusion_matrix
from sklearn.preprocessing import normalize

# Script to plot the confusion matrix for a language.
def make_stats(classification_file, languages):
    with open(classification_file, "r") as f:
        # From lines like "GE001_33 KO" make simple pairs (true, predicted) like [GE, KO]
        classifications = np.array([[l.split()[0][:2], l.split()[1]] for l in f.readlines()])
        y_true = classifications[:, 0]
        y_pred = classifications[:, 1]
        conf_matrix = confusion_matrix(y_true, y_pred, labels=languages)


        # Accuracy (sum along the diagonal of the conf. matrix)
        accuracy = np.trace(conf_matrix)/np.sum(conf_matrix)
        acc_msg = "Accuracy: {:.3f} ({}/{} classified correctly)"\
            .format(accuracy, np.trace(conf_matrix), np.sum(conf_matrix))
        print(acc_msg)

        # Pretty-printing the conf. matrix
        n = 4
        conf_matrix_nice = [languages[i].ljust(n) + " ".join([str(e).ljust(n) for e in row]) \
            for i, row in enumerate(conf_matrix)]
        conf_mtrx_msg = "Confusion matrix:\n{}{}\n{}".format(
                            " "*n,
                            " ".join([l.ljust(n) for l in languages]),
                            "\n".join(conf_matrix_nice))
        print(conf_mtrx_msg)
        return conf_matrix

if __name__ == "__main__":
    os.chdir("..")
    os.chdir("lre_results")
    classification_file=(os.path.join(os.getcwd(), "lre_tr_10000_en_10000", "classification"))
    languages = "AR BG CH CR CZ FR GE JA KO PL PO RU SP SW TH TU WU VN".split()
    conf_matrix = make_stats(classification_file, languages)
    norm_conf_matrix = normalize(conf_matrix, axis=1, norm='l1')
    conf_matrix = np.flip(conf_matrix, 0)
    norm_conf_matrix = np.flip(norm_conf_matrix, 0)
    plt.figure(figsize=(12, 10))
    ax = sns.heatmap(conf_matrix, cmap="binary", annot=True, fmt="d")
    ticks = []
    for i in range(len(languages)):
        ticks.append(i + 0.5)

    plt.xlabel("Predicted language")
    plt.xticks(ticks, labels=languages)
    plt.ylabel("True language")
    languages.reverse()
    plt.yticks(ticks, labels=languages, rotation=0)
    languages.reverse()
    for direction in ["top", "bottom", "left", "right"]:
        ax.spines[direction].set_color('black')
        ax.spines[direction].set_visible(True)
    plt.title("Example language confusion matrix")
    plt.savefig("conf_matrix_example.svg")
    plt.clf()

    ax = sns.heatmap(norm_conf_matrix, cmap="binary", annot=True, fmt=".2f")
    plt.xlabel("Predicted language")
    plt.xticks(ticks, labels=languages)
    plt.ylabel("True language")
    languages.reverse()
    plt.yticks(ticks, labels=languages, rotation=0)
    languages.reverse()
    for direction in ["top", "bottom", "left", "right"]:
        ax.spines[direction].set_color('black')
        ax.spines[direction].set_visible(True)
    plt.title("Example language confusion matrix (normalised)")
    plt.savefig("conf_matrix_norm_example.svg")
