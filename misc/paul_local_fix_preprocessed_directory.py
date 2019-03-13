# Will remove unnecessary folders like the separate ones for each language.
# Will also fix split enroll/test/validation data if it exists.
# NB - feats/vad needs to be recalculated - recombing isn't possible

import argparse, fileinput, os, sys,  shutil, fnmatch
from os.path import isfile, join, exists
def get_args():
    parser = argparse.ArgumentParser(description="Removes unneeded folders and fixes split data")
    parser.add_argument("--data-dir", type=str, required=True,
                    help="Path to data directory")
    args = parser.parse_args()
    return args

# Allow to run with Python 3 or 2.
def listdir_no_arguments():
    if sys.version_info >= (3, 0):
        return os.listdir()
    else:
        return os.listdir('.')

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text

def fix_file(scp_file):
    with open(scp_file, "r") as f:
        lines = f.readlines()
    fixed_lines = []
    prefix_len = len("/home/s1531206/")
    for line in lines:
        entry = line.split()
        if entry[1].startswith("/home/paul/"):
            # Skip already fixed
            #print("Data already fixed at {}".format(scp_file))
            return
        fixed_lines.append(entry[0] + " /home/paul/" + entry[1][prefix_len:])
    with open(scp_file, "w") as f:
        for line in fixed_lines:
            f.write(line + "\n")

def check_file(scp_file):
    with open(scp_file, "r") as f:
        lines = f.readlines()
    for line in lines:
        entry = line.split()
        prefix = entry[1]
        return prefix.startswith("/home/paul/gp-data/all_preprocessed")

def fix_language(exp_dir):
    all_subsets = os.listdir(exp_dir)
    for subset in all_subsets:
        feats_file = join(exp_dir, subset, "feats.scp")
        vad_file = join(exp_dir, subset, "vad.scp")
        if not exists(feats_file):
            print("Features file not found at {}".format(feats_file))
        else:
            fix_file(feats_file)
        if not exists(vad_file):
            print("VAD file not found at {}".format(vad_file))
        else:
            fix_file(vad_file)

def check_language(exp_dir):
    all_subsets = os.listdir(exp_dir)
    has_error = False
    for subset in all_subsets:
        feats_file = join(exp_dir, subset, "feats.scp")
        vad_file = join(exp_dir, subset, "vad.scp")
        if not exists(feats_file):
            has_error = True
            print("Features file not found at {}".format(feats_file))
        if not exists(vad_file):
            has_error = True
            print("VAD file not found at {}".format(vad_file))
    if not has_error:
        print("language in {} is A-ok".format(exp_dir))

def fix_directory(raw_data_dir, langs_to_fix):
    for lang in langs_to_fix:
        lang_dir = join(raw_data_dir, lang)
        if not exists(lang_dir):
            print("error: language not found in {}".format(lang_dir))
            return
        all_files = os.listdir(lang_dir)
        for file in all_files:
            file_path = join(lang_dir, file)
            if fnmatch.fnmatch(file, "*_" + lang + "_*.scp"):
                fix_file(file_path)
                #shutil.move(file_path, new_lang_dir)
def main():
    args = get_args()
    data_dir = args.data_dir
    assert exists(data_dir), "Directory not found at {}".format(data_dir)
    os.chdir(data_dir)
    changed_files = []

    for dirpath, dirnames, filenames in os.walk("."):
        for filename in [f for f in filenames if f.endswith(".scp") and not f.endswith("wav.scp")]:
            file_path = join(dirpath, filename)
            if not check_file(file_path):
                print("Need to fix file {}".format(file_path))
                changed_files.append(file_path)
                fix_file(file_path)
            else:
                print("File {} already fixed".format(file_path))
    with open("file-change-stats.txt", "w+") as f:
        for file in changed_files:
            f.write(file + "\n")

    langs_to_check = [ lang for lang in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, lang)) ]
    langs_to_check = [x for x in langs_to_check if x not in ("mfcc", "vad", "log", "output")]
    for lang in langs_to_check:
        exp_dir = os.path.join(data_dir, lang)
        assert os.path.exists(exp_dir), "Directory not found at {}".format(exp_dir)
        print("checking {} directory".format(lang))
        check_language(exp_dir)
    """
    langs_to_fix = os.listdir(data_dir)
    langs_to_fix = [x for x in langs_to_fix if x not in ("AR", "mfcc", "vad", "log", "output")]
    mfcc_dir = join(data_dir, "mfcc")
    vad_dir = join(data_dir, "vad")
    #for lang in langs_to_fix:
    #    exp_dir = os.path.join(data_dir, lang)
    #    assert os.path.exists(exp_dir), "Directory not found at {}".format(exp_dir)
    #    print("fixing {} directory".format(lang))
    #    fix_language(exp_dir)
    fix_directory(mfcc_dir, ["PO", "RU"])
    fix_directory(vad_dir, ["PO", "RU"])
    """

if __name__ == "__main__":
    main()
