# Produce a list of utterances for each language, given a configuration file
# in the format:
# LANGUAGE_CODE TRAINING_TIME (s)
# e.g. AR 600 gives 600 seconds of Arabic utterances
 # for the utt2num_frames file
import os, sys, shutil
import argparse
import numpy as np
from os.path import join, exists

def str2bool(v):
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

def get_args():
    parser = argparse.ArgumentParser(description="Gets utterance list for each language to a fixed length of time",
                                  epilog="Called by run.sh")
    parser.add_argument("--data-dir", type=str, required=True,
                    help="Path to data directory that the shortening will be done on")
    parser.add_argument("--conf-file-path", type=str, required=True,
                    help="Path to configuration file that will be used")
    parser.add_argument("--make-augmented", type=str2bool, default=False,
                    help="Whether or not this is for an augmented dataset. If true makes an extra list 3x as long")
    parser.add_argument("--make-rirs", type=str2bool, default=False,
                    help="Whether or not this is for a RIRS dataset. If true makes an extra list 2x as long")
    parser.add_argument("--is-training", type=str2bool, default=True,
                    help="Whether or not training data is being shortened")
    args = parser.parse_args()
    return args

def parse_utt2num_frames(utt2num_frames_path, langs, ref_path=None):
    with open(utt2num_frames_path, "r") as f:
        lines = f.readlines()
    if ref_path is not None:
        with open(ref_path, "r") as f:
            reflines = f.readlines()
        assert len(lines) == len(reflines), "Error: lengths do not match\tRef has {}\tFrames has {}".format(len(reflines), len(lines))
    data = {}
    for lang in langs:
        data[lang] = []
    for idx, line in enumerate(lines):
        if len(line) > 3:
            entry = line.split()
            lang_code = entry[0][:2]
            if lang_code in langs:
                actual_frames = int(entry[1])
                # Check if the shortened version would be too short
                if ref_path is not None:
                    ref_frames = int(reflines[idx].split()[1])
                    # 280 is a bit harsh, but protects against speed perturbation differences
                    if ref_frames <= 280 or actual_frames < 300:
                        continue
                    else:
                        data[lang_code].append((entry[0], actual_frames))
                else:
                    data[lang_code].append((entry[0], actual_frames))

    return data

def parse_config(conf_file_path):
    with open(conf_file_path, "r") as f:
        lines = f.readlines()
    langs = []
    lang_pairs = []
    for line in lines:
        # Skip past commented lines
        if line[0] == "#":
            continue
        entry = line.split()
        langs.append(entry[0])
        lang_pairs.append((entry[0], int(entry[1])))
    return langs, lang_pairs

def get_utterances(lang_data, target_seconds, summary_path):
    # Target number of frames (seconds*100)
    target_frames = target_seconds*100
    assert len(lang_data) != 0, "Empty language data list!"
    # Language code
    lang_code = lang_data[0][0][0:2]

    print("Getting utterances for {}".format(lang_code))
    # Current closest number of frames
    closest_number_frames = 0
    current_best_utterances = []
    # Randomise data order
    np.random.shuffle(lang_data)

    # Number of times to retry. 20 should be sufficient
    num_retries = 20
    curr_attempt_num = 1

    best_error = 9999999
    while(curr_attempt_num <= num_retries):
        print("Attempt #{}/{}".format(str(curr_attempt_num), str(num_retries)))
        curr_num_frames = 0
        temp_utterances = []
        i = 0
        n = len(lang_data)
        # Start by adding utterances until going over the target
        while (curr_num_frames < target_frames) and i < n:
            utt = lang_data[i][0]
            frames = lang_data[i][1]
            temp_utterances.append(utt)
            curr_num_frames += frames
            last_num_frames_added = frames
            i += 1
        # If we ran out of data
        if i == n:
            print("Ran out of data")
            current_best_utterances = temp_utterances
            closest_number_frames = curr_num_frames
            break
        else:
            # Remove the last utterance added as it shot over
            del temp_utterances[-1]
            curr_num_frames -= last_num_frames_added
            i -= 1

            # Only search remaining data for better result.
            search_data = lang_data[i:]
            # Number of frames left to fill in the last utterance
            target_last_utterance_frames = target_frames - curr_num_frames

            # Check the error here:
            error_before_last = target_last_utterance_frames

            (last_utterance, last_frames, error_after_last) = find_last_utterance(search_data, target_last_utterance_frames)

            # See if adding the extra frames actually helped or not
            if error_before_last < error_after_last:
                add_last = False
                error = error_before_last
            else:
                add_last = True
                error = error_after_last

            # If a better solution than before is found, update
            if error < best_error:
                best_error = error
                # Add on the last utterance if it improved the error
                if add_last == True:
                    temp_utterances.append(last_utterance)
                    curr_num_frames += last_frames
                current_best_utterances = temp_utterances
                closest_number_frames = curr_num_frames
                if error == 0:
                    print("Correct solution found!")
                    # Break out of the while loop
                    break

        curr_attempt_num += 1
        # Randomise data order
        np.random.shuffle(lang_data)

    final_output_utterances = current_best_utterances
    final_output_utterances.sort()
    final_number_frames = closest_number_frames
    error_percent = abs(final_number_frames - target_frames)*100/target_frames

    summary = "Language: {}\tTarget #frames: {}\tActual #frames: {}\tError: {}%".format(lang_code, str(target_frames), str(final_number_frames), str(error_percent))

    with open(summary_path, "a+") as f:
        f.write(summary + "\n")

    return final_output_utterances

def find_last_utterance(search_data, target_frames):
    min_error = 999999
    best_tuple = search_data[0]
    for utterance_tuple in search_data:
        curr_error = get_error(utterance_tuple[1], target_frames)
        if curr_error <= min_error:
            min_error = curr_error
            best_tuple = utterance_tuple
    return (best_tuple[0], best_tuple[1], min_error)

def get_error(test_frames, target_frames):
    return abs(test_frames - target_frames)

def find_multiplier(make_augmented, make_rirs):
    if make_augmented and make_rirs:
        return 3
    elif make_augmented and not make_rirs:
        return 2
    elif not make_augmented and make_rirs:
        return 1
    else:
        print("ERROR: Did not expect both to be false")
        return -1

def main():
    args = get_args()
    data_dir = args.data_dir
    os.chdir(data_dir)

    conf_file_path = args.conf_file_path
    assert exists(conf_file_path), "Configuration file not found in {}".format(conf_file_path)
    frames_file_path = join(data_dir, "utt2num_frames")
    ref_frames_file_path = None
    assert exists(frames_file_path), "utt2num_frames not found in {}".format(data_dir)
    if args.is_training:
        ref_frames_file_path = join(data_dir, "utt2num_frames_reference")
        assert exists(ref_frames_file_path), "utt2num_frames_ref not found in {}".format(data_dir)
    assert "utt2num_frames" in os.listdir(), "Frames file not located. Exiting..."
    print("Frames file found. Parsing...")
    langs, lang_pairs = parse_config(conf_file_path)

    data = parse_utt2num_frames(frames_file_path, langs, ref_path=ref_frames_file_path)

    output_path = join(data_dir, "utterances_shortened")
    summary_path = join(data_dir, "utterances_shortened_summary")
    open(output_path, "w").close()
    open(summary_path, "w").close()
    if args.make_augmented or args.make_rirs:
        output_path_clean = join(data_dir, "utterances_shortened_clean")
        summary_path_clean = join(data_dir, "utterances_shortened_clean_summary")
        open(output_path_clean, "w").close()
        open(summary_path_clean, "w").close()

    for lang_pair in lang_pairs:
        lang = lang_pair[0]
        target_seconds = lang_pair[1]
        # check for no data
        if len(data[lang]) == 0:
            print("No utterances found for lanuage: {}".format(lang))
            continue
        utterances = get_utterances(data[lang], target_seconds, summary_path)
        with open(output_path, "a+") as f:
            for utterance in utterances:
                f.write(utterance + "\n")
                if args.make_augmented:
                    f.write("sp0.9-" + utterance + "\n")
                    f.write("sp1.1-" + utterance + "\n")
                if args.make_rirs:
                    f.write(utterance + "-reverb\n")

        if args.make_augmented or args.make_rirs:
            multiplier = find_multiplier(args.make_augmented, args.make_rirs)
            # Filter out utterances that were found already
            data[lang] = [x for x in data[lang] if x[0] not in utterances]
            utterances_extra = []
            if len(data[lang]) == 0:
                with open(summary_path_clean, "a+") as f:
                    f.write(lang + " Error - ran out of data\n")
            else:
                utterances_extra = get_utterances(data[lang], target_seconds*multiplier, summary_path_clean)
                # Combine extra list with original to get list times original length
            utterances_extra += utterances
            utterances_extra.sort()
            with open(output_path_clean, "a+") as f:
                for utterance in utterances_extra:
                    f.write(utterance + "\n")

    print("Finished, summary of results stored in: {}".format(summary_path))

    print("Removing utt2len file since it's unnecessary")
    utt2len_file = join(data_dir, "utt2len")
    # If file exists, remove
    if exists(utt2len_file):
        os.remove(utt2len_file)
    else:
        print("Utt2len file not found in {} - this doesn't matter".format(utt2len_file))


if __name__ == "__main__":
    main()
