import os, sys, shutil, csv, re, pathlib
from os.path import isdir, join, exists

def calculate_f_score(classification_file, target_lang, beta=1):
    with open(classification_file, "r") as f:
        lines = f.readlines()
    true_pos_tl = 0
    false_pos_tl = 0
    true_neg_tl = 0
    false_neg_tl = 0
    for line in lines:
        entry = line.split()
        target = entry[0][:2]
        pred = entry[1]
        if target == target_lang and pred == target_lang:
            true_pos_tl += 1
        elif target == target_lang and pred != target_lang:
            false_neg_tl += 1
        elif target != target_lang and pred == target_lang:
            false_pos_tl += 1
        elif target != target_lang and pred != target_lang:
            true_neg_tl += 1
    precision = true_pos_tl / (true_pos_tl + false_pos_tl)
    recall = true_pos_tl / (true_pos_tl + false_neg_tl)
    f_beta = (1 + beta**2) * (precision * recall) / ((beta**2 * precision) + recall)
    return precision, recall, f_beta


def parse_no_language(expname):
    pattern = r'ad_.*tr_no_.*'
    if re.match(pattern, expname):
        return expname[-2:].upper()
    else:
        print("Was not an exclusive training set {}".format(expname))
        return "ALL"


def get_csv_header_row(expname):
    class_paths = ["classification_3s", "classification_10s", "classification_30s"]
    accs = ["accuracy_3s", "accuracy_10s", "accuracy_30s"]
    c_primaries = ["c_primary_3s", "c_primary_10s", "c_primary_30s"]
    base_labels = ["seed"] + class_paths + accs + c_primaries
    if expname.startswith("ad"):
        return ["expname", "training_languages", "excluded_languages"] + base_labels
    elif expname.startswith("da"):
        return ["expname", "rirs", "speed_augmentation", "clean", "baseline", "length"] + base_labels
    elif expname.startswith("lre"):
        return ["expname", "training_length", "enrollment_length"] + base_labels
    else:
        print("Unexpected marker")
        return None


def get_expname_data(expname):
    if expname[-2] == "_":
        seed = int(expname[-1])
    else:
        seed = 1

    if expname.startswith("ad"):
        excluded_lang = parse_no_language(expname)
        if expname.startswith("ad_all"):
            training_lang = "all"
        else:
            training_lang = "slavic"
        return [expname, training_lang, excluded_lang, seed]
    elif expname.startswith("da"):
        # Get truth values for if aug or rirs is true
        if "baseline" in expname:
            rirs = False
            aug = False
            clean = False
            baseline = True
        else:
            rirs = "rirs" in expname
            aug = "aug" in expname
            clean = "clean" in expname
            baseline = False
        if expname[-2] == "_":
            length = int("".join(filter(lambda x: x.isdigit(), expname[:-2])))
        else:
            length = int("".join(filter(lambda x: x.isdigit(), expname)))
        return [expname, rirs, aug, clean, baseline, length, seed]
    elif expname.startswith("lre"):
        if "baseline" in expname:
            return [expname, "all", "all", seed]
        entry = expname.split("_")
        training_length = int(entry[2])
        enrollment_length = int(entry[4])
        return [expname, training_length, enrollment_length, seed]


def get_classification_data(expname, root_data_dir):
    exp_path = join(root_data_dir, expname, "exp", "results")
    if not exists(exp_path):
        print("Results not found for {} at {}".format(expname, exp_path))
        return None, None, None
    classification_files = ["classification_3s", "classification_10s", "classification_30s"]
    results_files = ["results_3s", "results_10s", "results_30s"]
    class_paths = []
    for file in classification_files:
        file_path = join(exp_path, file)
        if not exists(file_path):
            class_paths.append("blank")
        else:
            class_paths.append(file_path)

    accuracies = []
    c_primaries = []
    for file in results_files:
        file_path = join(exp_path, file)
        if not exists(file_path):
            accuracies.append("blank")
            c_primaries.append("blank")
        else:
            accuracy, c_primary = parse_results(file_path)
            accuracies.append(accuracy)
            c_primaries.append(c_primary)

    return class_paths, accuracies, c_primaries


def parse_results(results_file_path):
    assert exists(results_file_path), "Results file path not found at {}".format(results_file_path)
    with open(results_file_path, "r") as f:
        lines = f.readlines()
    acc_line = lines[0]
    c_primary_line = lines[-1]
    acc = float(acc_line.split()[1])
    c_primary = float(c_primary_line.split()[2])
    return acc, c_primary


def write_to_csv(name, directory_path, headers, data):
    if not exists(directory_path):
        pathlib.Path(directory_path).mkdir(parents=True, exist_ok=True)
    file_path = join(directory_path, name + ".csv")
    with open(file_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(data)


def main():
    root_data_dir = "/" + join("home", "paul", "gp-data")
    assert exists(root_data_dir), "Path not found at {}".format(root_data_dir)
    all_expnames = os.listdir(root_data_dir)
    ad_all_expnames = list(filter(lambda k: k.startswith("ad_all"), all_expnames))
    ad_slavic_expnames = list(filter(lambda k: k.startswith("ad_slavic"), all_expnames))
    da_expnames = list(filter(lambda k: k.startswith("da"), all_expnames))
    lre_expnames = list(filter(lambda k: k.startswith("lre"), all_expnames))
    exp_sets = [ad_all_expnames, ad_slavic_expnames, da_expnames, lre_expnames]
    csv_names = ["ad_all_summary", "ad_slavic_summary", "da_summary", "lre_summary"]
    results_dir = join("/home", "paul", "language-ident-from-speech", "results")

    for idx, exp_set in enumerate(exp_sets):
        if len(exp_set) == 0:
            print("Nothing found here: {}".format(csv_names[idx]))
            continue
        headers = get_csv_header_row(exp_set[0])
        data_rows = []
        for exp in exp_set:
            categorical_labels = get_expname_data(exp)
            class_paths, accuracies, c_primaries = get_classification_data(exp, root_data_dir)
            if class_paths is None or accuracies is None or c_primaries is None:
                # data not found
                continue
            data_rows.append(categorical_labels + class_paths + accuracies + c_primaries)

        write_to_csv(csv_names[idx], results_dir, headers, data_rows)


if __name__ == "__main__":
    main()
