"""
A very simple error calculator.
Takes the scores file as input, prints the error rate for each language.
For each utterance, classifies it as the most likely of all the languages scores
"""
from __future__ import print_function
import re, os, argparse, sys, math, warnings, random



def get_args():
    parser = argparse.ArgumentParser(description="Calculates score for each language",
                                 epilog="Called by run.sh")
    parser.add_argument("--scores-dir", type=str, required=True,
                    help="Name of scores directory, e.g. exp/scores/");
    args = parser.parse_args()
    return args

def parse_file(score_filename):
    with open(score_filename, "r") as f:
        all_lines = f.readlines()
    # Assuming scores are in the format:
    # X utt_1 0.2
    # Y utt_1 0.4
    # Z utt_1 0.6
    # X utt_2 0.3
    # ...and so on
    languages = []
    for line in all_lines:
        entry = line.split(" ")
        new_lang = entry[0]
        if new_lang not in languages:
            languages.append(new_lang)
        else:
            break
    return languages, all_lines

def check_classification(language, data_portion):
    target_lang = data_portion[0][3:5]
    pred_lang = ""
    max_score = -9999
    for line in data_portion:
        entry = line.split(" ")
        score = float(entry[2])
        if score > max_score:
            max_score = score
            pred_lang = entry[0]
    if target_lang == pred_lang:
        return True
    else:
        return False


def get_language_error(data, language, step_size):
    num_correct = 0
    num_wrong = 0
    for idx, line in enumerate(data):
        if idx % step_size != 0:
            continue
        else:
            entry = line.split(" ")
            utt_lang = entry[1][0:2]
            if utt_lang == language:
                correct = check_classification(language, data[idx:idx+step_size])
            else:
                continue
        if correct:
            num_correct += 1
        else:
            num_wrong += 1
    total = num_correct + num_wrong
    return float(num_wrong)/total*100


def main():
    args = get_args()
    os.chdir(args.scores_dir)
    languages, data = parse_file("lang_eval_scores")
    step_size = len(languages)
    language_errors = []
    for language in languages:
        language_error = get_language_error(data, language, step_size)
        str_out = "Error for language {} is {:.4f}".format(language, language_error)
        print(str_out)
        language_errors.append(str_out)
    with open("lang_classification_errors", "w") as f:
        for error in language_errors:
            f.write(error + "\n")





if __name__ == "__main__":
    main()
