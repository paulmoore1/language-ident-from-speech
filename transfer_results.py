import os, sys, shutil

# Allow to run with Python 3 or 2.
def listdir_no_arguments():
    if sys.version_info >= (3, 0):
        return os.listdir()
    else:
        return os.listdir('.')

def main():
    copy_from_path = "/" + os.path.join("home", "s1531206", "gp-data")
    assert os.path.exists(copy_from_path), "Path not found at {}".format(copy_from_path)
    os.chdir(copy_from_path)

    copy_to_path = "/" + os.path.join("afs", "inf.ed.ac.uk", "user", "s15", "s1531206", "lre_results")
    if not os.path.exists(copy_to_path):
        os.mkdir(copy_to_path)

    exp_dirs = listdir_no_arguments()
    for exp_dir in exp_dirs:
        results_path_from = os.path.join(exp_dir, "exp", "results", "results")
        results_path_to = os.path.join(copy_to_path, exp_dir)

        if os.path.exists(os.path.join(results_path_to, "results")):
            print("Results already found!")
            continue

        if os.path.exists(results_path_from):
            print("Copying results")
            os.mkdir(results_path_to)
            shutil.copy(results_path_from, results_path_to)

if __name__ == "__main__":
    main()
