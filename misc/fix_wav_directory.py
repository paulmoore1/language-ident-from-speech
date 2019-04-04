import argparse, fileinput, os

# Script for fixing the wav.scp files
def get_args():
    parser = argparse.ArgumentParser(description="Replace all wav.scp and wav.scp.bak files with the corrected versions")
    parser.add_argument("--wav-dir", type=str, required=True,
                    help="Path to wav directory")
    args = parser.parse_args()
    return args

def fix_language(wav_dir, lang):
    files_to_fix = []
    wav_file = os.path.join(wav_dir, lang, "lists", "wav.scp")
    assert os.path.exists(wav_file), "No wav file path in {}".format(wav_file)
    files_to_fix.append(wav_file)
    backup_file = os.path.join(wav_dir, lang, "lists", "wav.scp.bak")
    if os.path.exists(backup_file):
        files_to_fix.append(backup_file)

    for file in files_to_fix:
        with fileinput.FileInput(file, inplace=True) as f:
            for line in f:
                print(line.replace("s1513472", "s1531206"), end='')


def main():
    args = get_args()
    wav_dir =args.wav_dir

    assert os.path.exists(wav_dir), "Directory not found in {}".format(wav_dir)
    os.chdir(wav_dir)
    langs = [ x for x in os.listdir() if len(x) == 2 ]
    print(langs)
    for lang in langs:
        fix_language(wav_dir, lang)

if __name__ == "__main__":
    main()
