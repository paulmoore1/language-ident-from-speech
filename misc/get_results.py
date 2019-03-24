import os, sys, shutil, csv, re
from os.path import isdir, join, exists

def parse_no_language(expname):
    pattern = r'ad_.*tr_no_.*'
    assert re.match(pattern, expname), "Was not an exclusive training set"
    return expname[-2:].upper()

def get_label_categories(expname):
    root_labels = ["classification_file", "accuracy", "c_primary"]
    base_labels = ["seed"]
    for i in [3 10 30]:
        base_labels += [x + "_" + str(i) + "s" for x in root_labels]
    if expname.startswith("ad"):
        return ["expname", "Training languages", "Enrollment languages"] + base_labels
    elif expname.startswith("da"):
        return ["expname", "RIRS", "Speed augmentation", "Clean", "Baseline"] + base_labels
    elif expname.startswith("lre"):
        return ["expname", "Training length", "Enrollment length"] + base_labels

def get_labels(expname):
    if expname.startswith("ad"):
        excluded_lang = parse_no_language(expname)
        

def main():
    root_data_dir = "/" + join("home", "paul", "gp-data")
    assert exists(root_data_dir), "Path not found at {}".format(root_data_dir)

    all_expnames = [x for x in os.listdir(root_data_dir) if os.isdir(x)]
    ad_all_expnames = filter(lambda k: k.startswith("ad_all"), all_expnames)
    ad_slavic_expnames = filter(lambda k: k.startswith("ad_slavic"), all_expnames)
    da_expnames = filter(lambda k: k.startswith("da"), all_expnames)
    lre_expnames = filter(lambda k: k.startswith("lre"), all_expnames)




if __name__ == "__main__":
    main()
