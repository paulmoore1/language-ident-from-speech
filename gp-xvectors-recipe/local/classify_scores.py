"""
A very simple error calculator.
Takes the scores file as input, prints the error rate for each language.
For each utterance, classifies it as the most likely of all the languages scores
"""
from __future__ import print_function
import re, os, argparse, sys, math, warnings, random, pprint
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
    args = parser.parse_args()
    return args

def classify(scores_file, output_file):
    with open(scores_file, "r") as f:
        lines = f.readlines()
        lines = np.array([line.split() for line in lines])
        languages = OrderedDict((x, True) for x in lines[:, 0]).keys()
        utterances = OrderedDict((x, True) for x in lines[:, 1]).keys()
        grouped_lines = OrderedDict((utt, np.array([line for line in lines if line[1] == utt])) for utt in utterances)

        with open(output_file, "w") as o:
            for utt, lines in grouped_lines.items():
                true_lang = utt[:2]
                scores = np.array(lines[:, 2])
                predicted_lang = lines[np.argmax(scores)][0]
                o.write("{} {}\n".format(true_lang, predicted_lang))

    return list(languages)

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
        
        conf_matrix_nice = [" ".join([str(e) for e in row]) for row in conf_matrix]
        conf_mtrx_msg = "Confusion matrix:\n{}\n{}".format("  ".join(languages), "\n".join(conf_matrix_nice))
        print(conf_mtrx_msg)

        with open(output_file, "w") as o:
            o.write("{}\n".format(acc_msg))
            o.write("{}\n".format(conf_mtrx_msg))

def main():
    args = get_args()

    # scores_file = os.path.join(args.scores_dir, "lang_eval_scores")
    # classification_file = os.path.join(args.scores_dir, "classification_results")
    # stats_file = os.path.join(args.scores_dir, "stats")
    
    # languages = classify(scores_file, classification_file)
    languages = args.language_list.split()

    make_stats(args.classification_file, args.output_file, languages)


if __name__ == "__main__":
    main()
