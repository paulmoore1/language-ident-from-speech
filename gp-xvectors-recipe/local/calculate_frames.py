import argparse
from math import log10, floor

def get_args():
    parser = argparse.ArgumentParser(description="Calculates number of frames per iteration")
    parser.add_argument("--num-train-frames", type=int, required=True,
                    help="Number of training frames")
    parser.add_argument("--num-repeats", type=int, required=True,
                    help="Number of repetitions")
    args = parser.parse_args()
    return args

def calculate_frames_per_iter(num_archives, num_train_frames, num_repeats):
    return int((num_train_frames*num_repeats)/(num_archives - 1))


def main():
    round_to_n = lambda x, n: round(x, -int(floor(log10(x))) + (n - 1))
    args = get_args()
    target_archives = 100
    target_frames = calculate_frames_per_iter(target_archives, args.num_train_frames, args.num_repeats)
    # Round to 2 s.f.
    target_frames = round_to_n(target_frames, 2)
    print(target_frames)


if __name__ == "__main__":
    main()
