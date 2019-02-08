import argparse


def get_args():
    parser = argparse.ArgumentParser(description="Calculates number of frames per iteration")
    parser.add_argument("--num-train-frames", type=int, required=True,
                    help="Number of training frames")
    parser.add_argument("--num-repeats", type=int, required=True,
                    help="Number of repetitions")
    args = parser.parse_args()
    return args


def calculate_frames_per_iter(num_archives, num_train_frames, num_repeats):
    return(num_train_frames*num_repeats)/(num_archives - 1)


def main():
    args = get_args()
    target_archives = 100
    target_frames = calculate_frames_per_iter(target_archives, args.num_train_frames, args.num_repeats)
    print(target_frames)


if __name__ == "__main__":
    main()
