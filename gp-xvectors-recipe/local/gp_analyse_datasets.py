
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
                line_split = [x.strip() for x in line.split(",")]
                
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                spk_ids = line_split[1:]
                datasets_dict[language]["eval"] = spk_ids
    except:
        pass

    try:
        with open("conf/gp_original_eval_spk.list", "r") as spk_file:
            for line in spk_file.readlines():
                line_split = [x.strip() for x in line.split(",")]
                
                # In case there is no split (lines like "AR TBA")
                if len(line_split) <= 2:
                    continue

                language = line_split[0]
                spk_ids = line_split[1:]
                datasets_dict[language]["test"] = spk_ids
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
        eval_set = gp_original_sets[L]["eval"]
        test_set = gp_original_sets[L]["test"]

        if (len(eval_set) + len(test_set)) == 0:
            print("No original split found for {}. Creating all four datasets.".format(L))
        else:
            print("Original split found for {}. Creating only the train and enroll datasets.".format(L))

        if L in langs_with_spk_data:
            print("Spk metadata found for {}. Using it for the split.".format(L))
        else
            print("No spk metadata found for {}. Doing random split.".format(L))
