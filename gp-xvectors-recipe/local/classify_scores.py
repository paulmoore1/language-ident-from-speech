"""
A very simple error calculator.
Takes the scores file as input, prints the error rate for each language.
For each utterance, classifies it as the most likely of all the languages scores
"""
from __future__ import print_function
import re, os, argparse, sys, math, warnings, random
import numpy as np
from collections import OrderedDict
from sklearn.metrics import confusion_matrix

def get_args():
    parser = argparse.ArgumentParser(description="Calculates score for each language",
                                 epilog="Called by run.sh")
    parser.add_argument("--classification-file", type=str, required=True,
                    help="File with all utterances, classification pairs, e.g. exp/classification")
    parser.add_argument("--output-file", type=str, required=True,
                    help="Name of file to which results will be dumped, e.g. exp/results")
    parser.add_argument("--language-list", type=str, required=True,
                    help="Ordered string of all languages, e.g. 'GE KO SW'")
    args = parser.parse_args()
    return args

def make_stats(classification_file, output_file, languages):
    with open(classification_file, "r") as f:
        classifications = np.array([[l.split()[0][:2], l.split()[1]] for l in f.readlines()])
        y_true = classifications[:, 0]
        y_pred = classifications[:, 1]
        conf_matrix = confusion_matrix(y_true, y_pred, labels=languages)

        accuracy = np.trace(conf_matrix)/np.sum(conf_matrix)
        acc_msg = "Accuracy: {:.3f} ({}/{} classified correctly)"\
            .format(accuracy, np.trace(conf_matrix), np.sum(conf_matrix))
        print(acc_msg)

        n = 4        
        conf_matrix_nice = [languages[i].ljust(n) + " ".join([str(e).ljust(n) for e in row]) for i, row in enumerate(conf_matrix)]
        conf_mtrx_msg = "Confusion matrix:\n{}{}\n{}".format(" "*n, " ".join([l.ljust(n) for l in languages]), \
            "\n".join(conf_matrix_nice))
        print(conf_mtrx_msg)

        with open(output_file, "w") as o:
            o.write("{}\n".format(acc_msg))
            o.write("{}\n".format(conf_mtrx_msg))

def main():
    args = get_args()

    languages = args.language_list.split()

    make_stats(args.classification_file, args.output_file, languages)


if __name__ == "__main__":
    main()
