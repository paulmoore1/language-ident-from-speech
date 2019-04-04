import os, sys, csv
from os.path import join, exists

# Script for extracting speaker metadata from GlobalPhone, storing it in a CSV file
def parse_speaker(speaker):
    lines = []
    file_read = False
    with open(speaker, "r") as f:
        try:
            lines = f.read().splitlines()
            file_read = True
        except:
            pass
    if not file_read:
        with open(speaker, "r", encoding="utf-16") as f:
            try:
                lines = f.read().splitlines()
            except:
                print("Still couldn't read file {}".format(speaker))

    gender = "unknown"
    age = -1
    language = "unknown"
    native_language = "unknown"
    dialect = "unknown"
    spk_id = -1

    for line in lines:
        if ";LANGUAGE:" in line:
            language = line[10:].strip()
        elif ";SEX:" in line:
            gender = line[5:].strip()
        elif ";AGE:" in line:
            if len(line) >= 5:
                age = line[5:].strip()
        elif ";NATIVE LANGUAGE:" in line:
            if len(line) >= 17:
                native_language = line[17:].strip()
        elif ";DIALECT:" in line:
            if len(line) >= 8:
                dialect = line[9:].strip()
        elif "SPEAKER ID" in line:
            spk_id = line[12:].strip()

    return [language, spk_id, gender, age, native_language, dialect]


def parse_speakers(gp_dir, lang_dir, lang):
    spk_dir = os.path.join(lang_dir, "spk")
    assert exists(spk_dir), "Directory {} not found".format(spk_dir)
    os.chdir(spk_dir)
    header_row = ["language", "spk_id", "gender", "age", "native_language", "dialect"]
    data_rows = []
    for speaker in os.listdir(spk_dir):
        data_rows.append(parse_speaker(speaker))
    os.chdir(gp_dir)
    data_rows.sort()
    with open(lang + ".csv", "w") as f:
        writer = csv.writer(f)
        writer.writerow(header_row)
        writer.writerows(data_rows)


def main():
    gp_dir = join("/home", "paul", "language-ident-from-speech", "gp_info")
    speakers_dir = join("/home", "paul", "language-ident-from-speech", "gp-xvectors-recipe", "conf")
    lang_dirs = [x for x in os.listdir(gp_dir) if os.path.isdir(join(gp_dir, x))]
    for lang in lang_dirs:
        print("Language: {}".format(lang))
        lang_dir = join(gp_dir, lang)
        if not os.path.exists(join(gp_dir, lang + ".csv")):
            parse_speakers(gp_dir, lang_dir, lang)
        else:
            print("Speaker CSV found for: {}".format(lang))

if __name__ == "__main__":
    main()
