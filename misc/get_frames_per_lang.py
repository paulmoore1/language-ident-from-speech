import os, sys, re
from os.path import join, exists, isdir

def get_num_frames(file_path, lang):
    if not exists(file_path):
        print("Filepath for {} not found: {}".format(lang, file_path))
        return -1
    total = 0
    with open(file_path, "r") as f:
        for line in f.readlines():
            entry = line.split()
            frames = int(entry[1])
            if frames >= 300:
                total += frames
    return total

def main():
    type = "enroll"
    root_data_dir = join("/home", "paul", "gp-data", "all_preprocessed")
    pattern = r'[A-Z][A-Z]'
    langs = [lang for lang in os.listdir(root_data_dir) if re.search(pattern, lang)]
    lang_stats = []
    for lang in langs:
        target_dirname = lang + "_" + type
        target_path = join(root_data_dir, lang, target_dirname, "utt2num_frames")
        frames = get_num_frames(target_path, lang)
        lang_stats.append((lang, frames))
    lang_stats.sort()
    with open(join(root_data_dir, "lang_stats_" + type + "_filtered"), "w") as f:
        for stat in lang_stats:
            f.write("Language : {}\tFrames: {}\n".format(stat[0], str(stat[1])))




if __name__ == '__main__':
    main()
