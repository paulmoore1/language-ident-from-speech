
def load_speakers():
    langs = ["AR", "BG", "CH", "CR", "CZ", "FR", "GE", "JA", "KO", "PL", 
             "PO", "RU", "SP", "SW", "TA", "TH", "TU", "VN", "WU"]
    spk_dict = {}
    for L in langs:
        speakers_for_language = {}
        try:
            with open("speakers/{}".format(L), "r") as spk_file:
                for line in spk_file.readlines():
                    line_splitted = line.split("|")
                    spk_id = line_splitted[0]
                    spk_gender = line_splitted[1]
                    spk_articles = line_splitted[2].split(",")
                    speakers_for_language[spk_id] = spk_articles
                spk_dict[L] = speakers_for_language
        except:
            pass
            
    return spk_dict

if __name__ == "__main__":
    spk_dict = load_speakers()