# Script to fix previously split data directory
# Will remove unnecessary folders like the separate ones for each language.
# Will also fix split enroll/test/validation data if it exists.
# NB - feats/vad needs to be recalculated - recombining isn't possible

import argparse, fileinput, os, sys,  shutil
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

def remove_langauges(exp_dir):
    languages = ["AR", "BG", "CH", "CR", "CZ", "FR", "GE", "JA", "KO", "PL", "PO",
                "RU", "SP", "SW", "TH", "TA", "TU", "WU", "VN"]
    for lang in languages:
        lang_dir_path = os.path.join(exp_dir, lang)
        if os.path.exists(lang_dir_path):
            print("Removing language {} from {}".format(lang, exp_dir))
            shutil.rmtree(lang_dir_path)

# Checks if a line is part of split data
def check_split(line):
    entry = line.split()
    return entry[0][-2] == "-"

def fix_lang_and_spk(set_dir):
    with open(os.path.join(set_dir, "utt2lang"), "r") as f:
        lang_lines = f.readlines()
    utt2lang_lines = []
    utt2spk_lines = []

    # Keep list to ensure that the order is the same when extractng from dict
    speakers = []
    languages = []

    spk_dict = {}
    lang_dict = {}

    spk2utt_lines = []
    lang2utt_lines = []

    if not check_split(lang_lines[0]):
        return
    for line in lang_lines:
        entry = line.split()
        suffix = entry[0][-2:]
        # Ignores utterances ending in "-2" or more
        if suffix == "-1":
            utt = entry[0][:-2]
            spk = entry[0].split("_")[0]
            if spk not in speakers:
                speakers.append(spk)
                spk_dict[spk] = []
            lang = entry[1]
            if lang not in languages:
                languages.append(lang)
                lang_dict[lang] = []

            utt2lang_lines.append(utt + " " + lang)
            utt2spk_lines.append(utt + " " + spk)
            spk_dict[spk].append(utt)
            lang_dict[lang].append(utt)
    if len(utt2lang_lines) == 0:
        print("Data already appears to be split")
        return

    with open(os.path.join(set_dir, "utt2lang"), "w") as f:
        for line in utt2lang_lines:
            f.write(line + "\n")

    with open(os.path.join(set_dir, "utt2spk"), "w") as f:
        for line in utt2spk_lines:
            f.write(line + "\n")

    with open(os.path.join(set_dir, "spk2utt"), "w") as f:
        for speaker in speakers:
            line = str(speaker)
            for utt in spk_dict[speaker]:
                line += (" " + utt)
            line += "\n"
            f.write(line)

    with open(os.path.join(set_dir, "lang2utt"), "w") as f:
        for lang in languages:
            line = str(lang)
            for utt in lang_dict[lang]:
                line += (" " + utt)
            line += "\n"
            f.write(line)

def fix_frames(set_dir):
    with open(os.path.join(set_dir, "utt2num_frames"), "r") as f:
        frame_lines = f.readlines()
    fixed_frame_lines = []
    n = len(frame_lines)
    i = 0
    if not check_split(frame_lines[0]):
        return
    for idx, line in enumerate(frame_lines):
        # Only loop from lines which haven't been skipped
        if idx == i:
            increase = get_line_idxs_in_row(idx, frame_lines, n)
            i += increase
            entry = line.split()
            utt = entry[0][:-2]
            # Since split is always equal
            frames = str(int(entry[1])*increase)
            fixed_frame_lines.append(utt + " " + frames)

    with open(os.path.join(set_dir, "utt2num_frames"), "w") as f:
        for line in fixed_frame_lines:
            f.write(line + "\n")

def fix_durs(set_dir):
    with open(os.path.join(set_dir, "utt2dur"), "r") as f:
        dur_lines = f.readlines()
    fixed_dur_lines = []
    n = len(dur_lines)
    i = 0
    if not check_split(dur_lines[0]):
        return
    for idx, line in enumerate(dur_lines):
        # Only loop from lines which haven't been skipped
        if idx == i:
            increase = get_line_idxs_in_row(idx, dur_lines, n)
            i += increase
            entry = line.split()
            utt = entry[0][:-2]
            # Since split is always equal
            frames = str(float(entry[1])*increase)
            fixed_dur_lines.append(utt + " " + frames)

    with open(os.path.join(set_dir, "utt2dur"), "w") as f:
        for line in fixed_dur_lines:
            f.write(line + "\n")

"""
def fix_feats(set_dir):
    with open(os.path.join(set_dir, "feats.scp"), "r") as f:
        feat_lines = f.readlines()
    revised_lines = []
    if not check_split(feat_lines[0]):
        return
    for line in feat_lines:
        entry = line.split()
        suffix = entry[0][-2:]
        # Ignores utterances ending in "-2" or more
        if suffix == "-1":
            utt = entry[0][:-2]
            id = entry[1]
            revised_lines.append(utt + " " + id)

    with open(os.path.join(set_dir, "feats.scp"), "w") as f:
        for line in revised_lines:
            f.write(line + "\n")

def fix_vad(set_dir):
    with open(os.path.join(set_dir, "vad.scp"), "r") as f:
        vad_lines = f.readlines()
    revised_lines = []
    if not check_split(vad_lines[0]):
        return
    for line in vad_lines:
        entry = line.split()
        suffix = entry[0][-2:]
        # Ignores utterances ending in "-2" or more
        if suffix == "-1":
            utt = entry[0][:-2]
            id = entry[1]
            revised_lines.append(utt + " " + id)


    with open(os.path.join(set_dir, "vad.scp"), "w") as f:
        for line in revised_lines:
            f.write(line + "\n")
"""
# Find the number of consecutive lines belonging to the same utterance.
def get_line_idxs_in_row(start_idx, frame_lines, n):
    i = 0
    # If this is the last index in the list, return immediately
    # NB this is one less since there is a blank line at the end of the file
    if start_idx == n - 1:
        return 1
    # Otherwise will continue
    curr_utt = frame_lines[start_idx].split("-")[0]
    while i + start_idx < n - 1 :
        i += 1
        # Protect against edge case by exiting if we start with the last one
        next_utt = frame_lines[start_idx + i].split("-")[0]
        if next_utt != curr_utt:
            return i
        # if not, continue loop until differnt utterance is found
    # Reached last element in list, so return i after increasing
    i += 1
    return i

def fix_split(exp_dir):
    print("Fixing split data in {}".format(exp_dir))
    sets = ["enroll", "eval", "test"]
    for set in sets:
        set_dir = os.path.join(exp_dir, set)
        # Check that the data is split
        if os.path.exists(os.path.join(set_dir, "segments")):
            fix_lang_and_spk(set_dir)
            fix_frames(set_dir)
            fix_durs(set_dir)
            #fix_vad(set_dir)
            #fix_feats(set_dir)
            os.remove(os.path.join(set_dir, "segments"))

def main():
    args = get_args()
    data_dir = args.data_dir

    assert os.path.exists(data_dir), "Directory not found in {}".format(data_dir)
    os.chdir(data_dir)
    exp_dirs = listdir_no_arguments()
    if "backup" in exp_dirs:
        exp_dirs.remove("backup")
    for exp_dir in exp_dirs:
        remove_langauges(exp_dir)
        fix_split(exp_dir)



if __name__ == "__main__":
    main()
