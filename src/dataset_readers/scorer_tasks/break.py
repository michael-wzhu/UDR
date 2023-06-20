from datasets import load_dataset, load_from_disk
import re, os
import json
from src.utils.dataset_utils import load_train_dataset


class BreakScorerTask:
    name = "break"
    question_field = "question_text"
    dataset_name = "break_data"
    split = "QDMR"
    prompt_field = "near_examples"
    def __init__(self,example_file,ds_size=None) -> None:
        current_path = os.getcwd()
        base_path = current_path.split("UDR")[0] + "UDR"
        dataset = load_from_disk(os.path.join(base_path, "data/break"))
        self.orig_training_dataset = load_train_dataset(dataset,size=ds_size)
        self.training_dataset = list(enumerate(self.orig_training_dataset))
        self.example_file = example_file
        with open(self.example_file) as f:
            self.data = json.load(f)
        

    def get_fields(self, entry,index=-1):
        test_question = self.remove_double_space(entry['test_question_text'])
        question = self.remove_double_space(entry['question_text'])
        decomposition = self.remove_double_space(self.reformat(entry['decomposition']))
        test_decomposition = self.remove_double_space(self.reformat(entry['test_decomposition']))
        return question,decomposition,test_question,test_decomposition

    @classmethod
    def remove_double_space(cls,string):
        return re.sub("[ ]{2,}", " ", string)
    @classmethod
    def reformat(cls,text):
        return " ".join([f"{i+1}#) {x.strip()}" for i,x in enumerate(text.split(";"))])
