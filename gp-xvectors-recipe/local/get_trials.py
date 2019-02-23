from __future__ import print_function
import re, os, argparse, sys, math, warnings, random

def get_args():
    parser = argparse.ArgumentParser(description="Writes trials for the given language",
                                 epilog="Called by run.sh")
    parser.add_argument("--test-dir", type=str, required=True,
                    help="Name of test directory, e.g. data/eval_test/");
    args = parser.parse_args()
    return args

def check_args(args):
    lang2utt_exists = os.path.isfile(os.path.join(args.test_dir, "lang2utt"))
    if not lang2utt_exists:
        print("lang2utt file does not exist in directory {}".format(args.test_dir))
        return False
    utt2lang_exists = os.path.isfile(os.path.join(args.test_dir, "utt2lang"))
    if not utt2lang_exists:
        print("utt2lang file does not exist in directory {}".format(args.test_dir))
        return False
    return True

def get_lang_and_utts(lang2utt_filename):
    with open(lang2utt_filename, "r") as f:
        lines = f.readlines()
    languages = []
    utts = []
    for line in lines:
        entry = line.split(" ")
        languages.append(entry[0])
        utts = utts + entry[1:]
        # strip newline from the final entry
        utts[-1] = utts[-1][:-1]
    return languages, utts

def generate_trials_list(languages, utts):
    filename_all = "trials_all"
    all_trials = []
    # Block comment writes file ordered by language.
    # Actual order is by utterance for easier classification.
    """
    for language in languages:
        filename_lang = "trials_" + language
        lang_trials = []
        for utt in utts:
            utt_lang = utt[0:2]
            if utt_lang == language:
                example = language + " " + utt + " target"
            else:
                example = language + " " + utt + " nontarget"
            lang_trials.append(example)
            all_trials.append(example)
        with open(filename_lang, "w") as f:
            for trial in lang_trials:
                f.write(trial + "\n")
    """
    for utt in utts:
        for language in languages:
            utt_lang = utt[0:2]
            if utt_lang == language:
                example = language + " " + utt + " target"
            else:
                example = language + " " + utt + " nontarget"
            all_trials.append(example)

    with open(filename_all, "w") as f:
        for trial in all_trials:
            f.write(trial + "\n")

def main():
    args = get_args()
    os.chdir(args.test_dir)
    if not check_args(args):
        print("Error in arguments")
        sys.exit(1)
    languages, utts = get_lang_and_utts("lang2utt")
    generate_trials_list(languages, utts)

if __name__ == "__main__":
    main()
