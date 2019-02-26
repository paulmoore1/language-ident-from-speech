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

def fix_file(scp_file, language):
    with open(scp_file, "r") as f:
        lines = f.readlines()
    fixed_lines = []

    for line in lines:
        entry = line.split()
        (head, tail) = os.path.split(entry[1])
        # Leave it if it's already fine
        if head[-2:] == language:
            print("Skipping {}".format(scp_file))
            return
        else:
            fixed_lines.append(entry[0] + " " + head + "/" + language + "/" + tail)
    with open(scp_file, "w") as f:
        for line in fixed_lines:
            f.write(line + "\n")

def fix_language(exp_dir, language):
    all_subsets = os.listdir(exp_dir)
    for subset in all_subsets:
        feats_file = os.path.join(exp_dir, subset, "feats.scp")
        vad_file = os.path.join(exp_dir, subset, "vad.scp")
        assert os.path.exists(feats_file), "Features file not found at {}".format(feats_file)
        assert os.path.exists(vad_file), "VAD file not found at {}".format(vad_file)
        fix_file(feats_file, language)
        fix_file(vad_file, language)

def fix_directory(raw_data_dir, langs_to_fix):
    all_files = [f for f in os.listdir(raw_data_dir) if isfile(join(raw_data_dir, f))]
    for lang in langs_to_fix:
        new_lang_dir = join(raw_data_dir, lang)
        if not exists(new_lang_dir):
            os.mkdir(new_lang_dir)
        else:
            print("Directory for {} already appears to be fixed".format(lang))
            continue
        for file in all_files:
            file_path = join(raw_data_dir, file)
            if fnmatch.fnmatch(file, "*_" + lang + "_*.ark"):
                shutil.move(file_path, new_lang_dir)
            elif fnmatch.fnmatch(file, "*_" + lang + "_*.scp"):
                fix_file(file_path, lang)
                shutil.move(file_path, new_lang_dir)
def main():
    args = get_args()
    data_dir = args.data_dir
    assert exists(data_dir), "Directory not found at {}".format(data_dir)
    os.chdir(data_dir)
    langs_to_fix = ["AR", "BG", "CH", "CR", "CZ", "FR", "GE"]
    mfcc_dir = join(data_dir, "mfcc")
    vad_dir = join(data_dir, "vad")
    for lang in langs_to_fix:
        exp_dir = os.path.join(data_dir, lang)
        assert os.path.exists(exp_dir), "Directory not found at {}".format(exp_dir)
        fix_language(exp_dir, lang)
    fix_directory(mfcc_dir, langs_to_fix)
    fix_directory(vad_dir, langs_to_fix)


if __name__ == "__main__":
    main()
