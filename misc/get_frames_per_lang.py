import os, sys, re
from os.path import join, exists, isdir

def get_num_frames(file_path, lang, filter=False):
    if not exists(file_path):
        print("Filepath for {} not found: {}".format(lang, file_path))
        return -1
    total = 0
    with open(file_path, "r") as f:
        for line in f.readlines():
            entry = line.split()
            frames = int(entry[1])
            if filter:
                if frames >= 300:
                    total += frames
            else:
                total += frames
    return total

def main():
    root_data_dir = join("/home", "paul", "gp-data", "all_preprocessed")
    home_dir = join("/home", "paul", "language-ident-from-speech")
    pattern = r'[A-Z][A-Z]'
    langs = [lang for lang in os.listdir(root_data_dir) if re.search(pattern, lang)]

    types = ["train", "enroll", "eval", "test"]
    for type in types:
        lang_frames = []
        lang_hrs = []
        for lang in langs:
            target_dirname = lang + "_" + type
            target_path = join(root_data_dir, lang, target_dirname, "utt2num_frames")
            frames = get_num_frames(target_path, lang)
            hours = frames / 360000
            lang_frames.append((lang, frames))
            lang_hrs.append((lang, hours))
        lang_frames.sort()
        lang_hrs.sort()
        with open(join(home_dir, "lang_stats_" + type + ".txt"), "w") as f:
            for stat in lang_frames:
                f.write("Language : {}\tFrames: {}\n".format(stat[0], str(stat[1])))

        with open(join(home_dir, "lang_hrs_" + type + ".txt"), "w") as f:
            for hr in lang_hrs:
                f.write("Language : {}\tHours: {}\n".format(hr[0], str(hr[1])))
    lang_stats = []
    lang_hrs = []
    for lang in langs:
        tot_frames = 0
        tot_hrs = 0
        for type in types:
            target_dirname = lang + "_" + type
            target_path = join(root_data_dir, lang, target_dirname, "utt2num_frames")
            frames = get_num_frames(target_path, lang)
            tot_frames += frames
            tot_hrs += (frames / 360000)
        lang_stats.append((lang, tot_frames))
        lang_hrs.append((lang, tot_hrs))
        lang_stats.sort()
        lang_hrs.sort()
        with open(join(home_dir, "lang_stats_all.txt"), "w") as f:
            for stat in lang_stats:
                f.write("Language : {}\tFrames: {}\n".format(stat[0], str(stat[1])))
        with open(join(home_dir, "lang_hrs_all.txt"), "w") as f:
            for hr in lang_hrs:
                f.write("Language : {}\tHours: {}\n".format(hr[0], str(hr[1])))





if __name__ == '__main__':
    main()
