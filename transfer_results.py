import os, sys

# Allow to run with Python 3 or 2.
def listdir_no_arguments():
    if sys.version_info >= (3, 0):
        return os.listdir()
    else:
        return os.listdir('.')

def main():
    os.chdir("..")
    os.chdir("gp-data")
    exp_dirs = listdir_no_arguments()
    for exp_dir in exp_dirs:
        is os.path.exists()

if __name__ == "__main__":
    main()
