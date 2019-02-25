import os, sys, re, csv
import numpy as np
import seaborn as sns
import pandas as pd
import matplotlib.pyplot as plt

# Allow to run with Python 3 or 2.
def listdir_no_arguments():
    if sys.version_info >= (3, 0):
        return os.listdir()
    else:
        return os.listdir('.')

def parse_experiment(exp_dir):
    m = re.search(r".*_tr_(.*)_en_(.*).*", exp_dir)
    training = str(m.group(1))
    enroll = str(m.group(2))
    if enroll[-2] == "_":
        enroll = enroll[:-2]

    results_path = os.path.join(exp_dir, "results")
    with open(results_path, "r") as f:
        all_lines = f.readlines()

    accuracy = float(all_lines[0].split(" ")[1])
    c_primary = float(all_lines[-1].split(" ")[-1])

    return ((training, enroll, accuracy, c_primary))

def fix_dict(input_dict):
    for key in input_dict:
        old_entry = input_dict[key]
        mean_acc = np.mean(old_entry)
        std_acc = np.std(old_entry)
        input_dict[key] = (mean_acc, std_acc)

def create_results_csv():
    all_expts = listdir_no_arguments()
    if "results.csv" in all_expts:
        all_expts.remove("results.csv")
    train_vals = ["500", "1000", "5000", "10000"]
    enroll_vals = ["500", "1000", "5000", "10000"]
    accs_dict = {}
    c_dict = {}
    for exp_dir in all_expts:
        exp_train, exp_enroll, accuracy, c_primary = parse_experiment(exp_dir)
        id = exp_train + " " + exp_enroll
        if accs_dict.get(id, "NONE") == "NONE":
            # Format = (Accuracy (mean), Standard Deviation, #accuracies)
            accs_dict[id] = [accuracy]
        else:
            accs_dict[id].append(accuracy)
        if c_dict.get(id, "NONE") == "NONE":
            # Format = (C-primary (mean), Standard Deviation, #accuracies)
            c_dict[id] = [c_primary]
        else:
            c_dict[id].append(c_primary)

    fix_dict(accs_dict)
    fix_dict(c_dict)

    with open('results.csv', "w") as f:
        top_row = ["Train_Length", "Enroll_Length", "Mean_Accuracy", "Std_Dev_Accuracy", "Mean_C_primary", "Std_Dev_C_primary"]
        writer = csv.writer(f)
        writer.writerow(top_row)
        data_rows = []
        for key in accs_dict:
            train_length = int(key.split(" ")[0])
            enroll_length = int(key.split(" ")[1])
            mean_accuracy = accs_dict[key][0]
            std_deviation_acc = accs_dict[key][1]
            mean_c_primary = c_dict[key][0]
            std_deviation_c = c_dict[key][1]
            data_rows.append([train_length, enroll_length, mean_accuracy, std_deviation_acc, mean_c_primary, std_deviation_c])
        # Sort data by first two columnss
        data_rows.sort(key = lambda x: x[1])
        data_rows.sort(key = lambda x: x[0])
        writer.writerows(data_rows)

    print("Finished writing results")

def main():
    os.chdir("..")
    results_dir = os.path.join(os.getcwd(), "lre_results")
    assert(os.path.exists(results_dir)), "No results found"
    os.chdir(results_dir)
    #create_results_csv()
    df = pd.read_csv("results.csv")
    accs_df = df.drop(columns=["Std_Dev_Accuracy", "Mean_C_primary", "Std_Dev_C_primary"])
    c_primary_df = df.drop(columns=["Std_Dev_Accuracy", "Mean_Accuracy", "Std_Dev_C_primary"])

    accs_df = accs_df.pivot(index="Train_Length", columns="Enroll_Length")
    c_primary_df = c_primary_df.pivot(index="Train_Length", columns="Enroll_Length")
    sns.heatmap(c_primary_df, cmap="copper_r", annot=True, xticklabels="auto", yticklabels="auto")
    plt.xlabel("Enrollment length (seconds)")
    plt.xticks([0.5, 1.5, 2.5, 3.5], labels=["500", "1000", "5000", "10000"], rotation=0)
    plt.ylabel("Training length (seconds)")
    plt.yticks([0.5, 1.5, 2.5, 3.5])
    plt.title("Mean C-primary score")
    plt.savefig("c_primary_heatmap.png")
    plt.clf()

    sns.heatmap(accs_df, cmap="copper", annot=True, xticklabels="auto", yticklabels="auto")
    plt.xlabel("Enrollment length (seconds)")
    plt.xticks([0.5, 1.5, 2.5, 3.5], labels=["500", "1000", "5000", "10000"], rotation=0)
    plt.ylabel("Training length (seconds)")
    plt.yticks([0.5, 1.5, 2.5, 3.5])
    plt.title("Mean Accuracies")
    plt.savefig("accs_heatmap.png")


if __name__ == "__main__":
    main()
