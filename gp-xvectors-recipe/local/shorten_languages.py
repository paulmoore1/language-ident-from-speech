# Produce a list of utterances for each language, given a configuration file
# in the format:
# LANGUAGE_CODE TRAINING_TIME (s)
# e.g. AR 600 gives 600 seconds of Arabic utterances
 # for the utt2num_frames file
import os, sys
import argparse
import numpy as np

def get_args():
    parser = argparse.ArgumentParser(description="Gets utterance list for each language to a fixed length of time",
                                  epilog="Called by run.sh")
    parser.add_argument("--data-dir", type=str, required=True,
                    help="Path to data directory that the shortening will be done on")
    parser.add_argument("--conf-file-path", type=str, required=True,
                    help="Path to configuration file that will be used")
    args = parser.parse_args()
    return args

def parse_utt2num_frames(utt2num_frames_path, langs):
    with open(utt2num_frames_path, "r") as f:
        lines = f.readlines()
    data = {}
    for lang in langs:
        data[lang] = []
    for line in lines:
        # Check that it's not a blank line
        if len(line) > 3:
            entry = line.split()
            lang_code = entry[0][:2]
            if lang_code in langs:
                data[lang_code].append((entry[0], int(entry[1])))
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

def get_utterances(lang_data, target_seconds, output_path, summary_path):
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

    # Number of times to retry. 10 should be sufficient
    num_retries = 10
    curr_attempt_num = 1

    best_error = 9999999
    while(curr_attempt_num <= num_retries):
        print("Attempt #{}/{}".format(str(curr_attempt_num), str(num_retries)))
        curr_num_frames = 0
        temp_utterances = []
        i = 0
        # Start by adding utterances until going over the target
        while (curr_num_frames < target_frames):
            temp_utterances.append(lang_data[i][0])
            curr_num_frames += lang_data[i][1]
            last_num_frames_added = lang_data[i][1]
            i += 1

        # Remove the last utterance added as it shot over
        del temp_utterances[-1]
        curr_num_frames -= last_num_frames_added

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
    error_percent = best_error*100/target_frames

    summary = "Language: {}\tTarget #frames: {}\tActual #frames: {}\tError: {}%".format(lang_code, str(target_frames), str(final_number_frames), str(error_percent))

    with open(output_path, "a+") as f:
        for utterance in final_output_utterances:
            f.write(utterance + "\n")

    with open(summary_path, "a+") as f:
        f.write(summary + "\n")

def find_last_utterance(search_data, target_frames):
    min_error = 999999
    best_tuple = None
    for utterance_tuple in search_data:
        curr_error = get_error(utterance_tuple[1], target_frames)
        if curr_error <= min_error:
            min_error = curr_error
            best_tuple = utterance_tuple
    return (best_tuple[0], best_tuple[1], min_error)

def get_error(test_frames, target_frames):
    return abs(test_frames - target_frames)

def main():
    args = get_args()
    data_dir = args.data_dir
    os.chdir(data_dir)

    conf_file_path = args.conf_file_path
    assert os.path.exists(conf_file_path), "Configuration file not found in {}".format(conf_file_path)
    frames_file_path = os.path.join(data_dir, "utt2num_frames")
    assert os.path.exists(frames_file_path), "utt2num_frames not found in {}".format(data_dir)

    assert "utt2num_frames" in os.listdir(), "Frames file not located. Exiting..."
    print("Frames file found. Parsing...")
    langs, lang_pairs = parse_config(conf_file_path)

    data = parse_utt2num_frames(frames_file_path, langs)

    output_path = os.path.join(data_dir, "utterances_shortened")
    summary_path = os.path.join(data_dir, "utterances_shortened_summary")
    # Delete files if they exist so that we can begin a new one from scratch each time
    if os.path.exists(output_path):
        os.remove(output_path)
    if os.path.exists(summary_path):
        os.remove(summary_path)

    for lang_pair in lang_pairs:
        lang = lang_pair[0]
        target_seconds = lang_pair[1]
        get_utterances(data[lang], target_seconds, output_path, summary_path)

    print("Finished, summary of results stored in: {}".format(summary_path))

    print("Filtering utt2len file since the default fixing ignores it")
    utt2len_file = os.path.join(data_dir, "utt2len")
    # If file doesn't exist, return
    if not os.path.exists(utt2len_file):
        print("File not found in {}".format(utt2len_file))
    else:
        with open(utt2len_file, "r") as f:
            original_lines = f.read().splitlines()
        with open(output_path, "r") as f:
            valid_utterances = f.read().splitlines()
        new_lines = []
        for line in original_lines:
            entry = line.split()
            utterance = entry[0]
            if utterance in valid_utterances:
                new_lines.append(line)
        with open(utt2len_file, "w") as f:
            for line in new_lines:
                f.write(line + "\n")


if __name__ == "__main__":
    main()
