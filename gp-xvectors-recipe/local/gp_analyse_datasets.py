import re
from math import ceil
import random

def load_speaker_data(langs):
    spk_dict = {}
    for L in langs:
        speakers_for_language = {}
        try:
            with open("speakers/{}_spk_metadata".format(L), "r") as spk_file:
                for line in spk_file.readlines():
                    line_splitted = line.split("|")
                    spk_id = line_splitted[0]
                    spk_gender = line_splitted[1]
                    spk_articles = line_splitted[2].split(",")
                    spk_articles = [article.strip() for article in spk_articles]
                    speakers_for_language[spk_id] = spk_articles
                spk_dict[L] = speakers_for_language
        except:
            pass
    # print(spk_dict["RU"])
            
    return spk_dict

def load_all_speakers(langs):
    spk_lists = {}
    for L in langs:
        speakers_for_language = []
        try:
            with open("speakers/{}_all_spk".format(L), "r") as spk_file:
                for line in spk_file.readlines():
                    spk_id = line.strip()
                    speakers_for_language.append(spk_id)
        except:
            pass
        spk_lists[L] = speakers_for_language

    return spk_lists

def load_original_datasets(langs):
    datasets_dict = {L: {"eval": [], "test": []} for L in langs}

    try:
        with open("conf/gp_original_dev_spk.list", "r") as spk_file:
            for line in spk_file.readlines():
                line_split = [x.strip() for x in re.split('\t| ', line)]
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                spk_ids = line_split[1:]
                for spk_id in spk_ids:
                    datasets_dict[language]["eval"].append(spk_id)
    except:
        pass

    try:
        with open("conf/gp_original_eval_spk.list", "r") as spk_file:
            for line in spk_file.readlines():
                line_split = [x.strip() for x in re.split('\t| ', line)]
                
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                spk_ids = line_split[1:]
                for spk_id in spk_ids:
                    datasets_dict[language]["test"].append(spk_id)
    except:
        pass

    return datasets_dict


if __name__ == "__main__":
    num_spks = {"AR": 78, "BG": 77, "CH": 132, "CR": 92, "CZ": 102, "FR": 100, "GE": 77, "JA": 144, "KO": 100, "PL": 99, "PO": 100, "RU": 115, "SP": 100, "SW": 98, "TA": 47, "TH": 98, "TU": 100, "VN": 129, "WU": 41}
    all_langs = ["AR", "BG", "CH", "CR", "CZ", "FR", "GE", "JA", "KO", "PL", "PO", "RU", "SP", "SW", "TA", "TH", "TU", "VN", "WU"]
    
    spk_article_dict = load_speaker_data(all_langs)
    langs_with_spk_data = list(spk_article_dict.keys())
    print("SPK data exists for these langs: {}".format(langs_with_spk_data))
    langs_for_random_split = [lang for lang in all_langs if lang not in langs_with_spk_data]
    print("SPK data NOT found for these langs: {}".format(langs_for_random_split))

    all_spk_lists = load_all_speakers(all_langs)

    gp_original_sets = load_original_datasets(all_langs)

    for L in all_langs:
        print("Language {}".format(L))
        eval_set = gp_original_sets[L]["eval"]
        test_set = gp_original_sets[L]["test"]
        available_spks = [spk_id for spk_id in all_spk_lists[L] if \
                          (spk_id not in eval_set and spk_id not in test_set)]
        # print("Choosing from speakers: {}".format(available_spks))
        
        spks_test = []
        spks_eval = []
        spks_enroll = []
        spks_train = []

        if (len(eval_set) + len(test_set)) == 0:
            print("No original split found for {}. Creating all four datasets.".format(L))
            num_enroll = int(ceil(0.1*num_spks[L]))
            num_test = num_enroll
            num_eval = num_enroll

            if L in langs_with_spk_data:
                print("Spk metadata found for {}. Using it for the split.".format(L))
                # The most complicated case: 4 non-random sets
                sets_valid = False
                attempt_counter = 0
                threshold = 0
                max_iter = 100
                while not sets_valid:
                    spks_test = random.sample(available_spks, num_test)
                    spks_eval = random.sample([spk_id for spk_id in available_spks if spk_id not in spks_test], num_eval)
                    spks_enroll = random.sample([spk_id for spk_id in available_spks if (spk_id not in spks_test) and (spk_id not in spks_eval)], num_enroll)
                    spks_train = [spk_id for spk_id in available_spks if (spk_id not in spks_test) and (spk_id not in spks_eval) and (spk_id not in spks_enroll)]
                    
                    test_articles = []
                    for spk_id in spks_test:
                        test_articles = test_articles + spk_article_dict[L][spk_id]                    
                    test_articles = set(test_articles)
                    
                    eval_articles = []
                    for spk_id in spks_eval:
                        eval_articles = eval_articles + spk_article_dict[L][spk_id]                    
                    eval_articles = set(eval_articles)

                    enroll_articles = []
                    for spk_id in spks_enroll:
                        enroll_articles = enroll_articles + spk_article_dict[L][spk_id]                    
                    enroll_articles = set(enroll_articles)

                    train_articles = []
                    for spk_id in spks_train:
                        train_articles = train_articles + spk_article_dict[L][spk_id]
                    train_articles = set(train_articles)

                    overlap = len(test_articles) + len(eval_articles) + len(enroll_articles) + len(train_articles) \
                              - len(train_articles.intersection(test_articles, eval_articles, enroll_articles))

                    if len(overlap) <= threshold:
                        print("\nVALID SPLIT FOUND ({})\nTest: {}\nEval: {}\nEnroll: {}\nTrain: {}\nVALID SPLIT FOUND\n"\
                              .format(attempt_counter, spks_test, spks_eval, spks_enroll, spks_train))
                        break
                    else:
                        attempt_counter += 1
                        if attempt_counter % max_iter == 0:
                            threshold += 1
                            print("Looking for splits with <= {} overlaps.".format(threshold))
                        pass
                        # print("Invalid split (overlap: {}).".format(len(overlap)))
            else:
                print("No spk metadata found for {}. Doing random split.".format(L))
                # The easy case: 4 random sets
                spks_test = random.sample(available_spks, num_test)
                spks_eval = random.sample([spk_id for spk_id in available_spks if spk_id not in spks_test], num_eval)
                spks_enroll = random.sample([spk_id for spk_id in available_spks if (spk_id not in spks_test) and (spk_id not in spks_eval)], num_enroll)
                spks_train = [spk_id for spk_id in available_spks if (spk_id not in spks_test) and (spk_id not in spks_eval) and (spk_id not in spks_enroll)]
                print("Testing speakers: {}".format(spks_test))
                print("Evaluation speakers: {}".format(spks_eval))
                print("Enrollment speakers: {}".format(spks_enroll))
                print("Training speakers: {}".format(spks_train))
                # continue
            
            with open("speakers/{}_test".format(L), "w") as f:
                f.write(' '.join(spks_test))
            with open("speakers/{}_eval".format(L), "w") as f:
                f.write(' '.join(spks_eval))
            with open("speakers/{}_enroll".format(L), "w") as f:
                f.write(' '.join(spks_enroll))
            with open("speakers/{}_train".format(L), "w") as f:
                f.write(' '.join(spks_train))

        else:
            print("Original split found for {}. Creating only the train and enroll datasets.".format(L))
            num_enroll = int(ceil(0.1*num_spks[L]))
            print("Choosing {} enrollment speakers.".format(num_enroll))
            if L in langs_with_spk_data:
                print("Spk metadata found for {}. Using it for the split.".format(L))
                # The complicated case: 2 non-random sets
                sets_valid = False
                attempt_counter = 0
                threshold = 0
                max_iter = 1000
                while not sets_valid:
                    spks_enroll = random.sample(available_spks, num_enroll)
                    spks_train = [spk_id for spk_id in available_spks if spk_id not in spks_enroll]
                    
                    enroll_articles = []
                    for spk_id in spks_enroll:
                        enroll_articles = enroll_articles + spk_article_dict[L][spk_id]
                    
                    enroll_articles = set(enroll_articles)
                    
                    train_articles = []
                    for spk_id in spks_train:
                        train_articles = train_articles + spk_article_dict[L][spk_id]
                    train_articles = set(train_articles)

                    overlap = list(train_articles.intersection(enroll_articles))
                    if len(overlap) <= threshold:
                        print("\nVALID SPLIT FOUND ({})\nTrain: {}\nEnroll: {}\nVALID SPLIT FOUND\n".format(attempt_counter, spks_train, spks_enroll))
                        break
                    else:
                        attempt_counter += 1
                        if attempt_counter % max_iter == 0:
                            threshold += 1
                            print("Looking for splits with <= {} overlaps.".format(threshold))
                        pass
                        # print("Invalid split (overlap: {}).".format(len(overlap)))
            else:
                print("No spk metadata found for {}. Doing random split.".format(L))
                # The easiest case: 2 random sets
                spks_enroll = random.sample(available_spks, num_enroll)
                spks_train = [spk_id for spk_id in available_spks if spk_id not in spks_enroll]
                print("Enrollment speakers: {}".format(spks_enroll))
                print("Training speakers: {}".format(spks_train))
                
            with open("speakers/{}_enroll".format(L), "w") as f:
                f.write(' '.join(spks_enroll))
            with open("speakers/{}_train".format(L), "w") as f:
                f.write(' '.join(spks_train))
