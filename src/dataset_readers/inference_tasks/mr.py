import os

from datasets import load_from_disk, Dataset, concatenate_datasets
from src.utils.dataset_utils import load_train_dataset

import json
from src.utils.tokenizer_utils import get_length
from Channel_LM_Prompting.util import get_one_prompt
from src.utils.cls_utils import get_test_labels, change_prompt_template


def set_length(example, idx,**kwargs):
    tokenizer = kwargs['tokenizer']
    q_field = example['sentence']
    a_field = get_one_prompt('mr', kwargs['template_idx'], example['label'])
    prompt_qa = f"{q_field}\t{a_field}"
    example['prompt_qa'] = prompt_qa
    example['prompt_len'] = get_length(tokenizer,prompt_qa)
    return example


class MRInferenceTask:
    name = "mr"

    def __init__(self, prompt_file, tokenizer, ds_size=None, template_idx=1):
        self.prompt_file = prompt_file
        with open(self.prompt_file) as f:
            self.prompts = json.load(f)
        if template_idx != 1:
            self.prompts = change_prompt_template(self.prompts, 'mr', template_idx)
        self.prompts = get_test_labels(self.prompts, 'mr', template_idx)
        dataset = load_dataset("KaiLv/UDR_MR")

        self.hf_dataset = load_train_dataset(dataset, size=ds_size, listify=False)
        self.hf_dataset = self.hf_dataset.map(set_length, with_indices=True, fn_kwargs={'tokenizer': tokenizer, "template_idx": template_idx})
        self.training_dataset = list(self.hf_dataset)
        self.postfix = ''

    @classmethod
    def postproccess(cls, string):
        return string

    def get_fields(self, entry):
        question = entry['sentence'] if "sentence" in entry else entry['question']
        answer = entry['label'] if "label" in entry else int(entry['answers'][0])
        idx_list = [p['id'] for p in entry['ctxs']]
        prompts = self.hf_dataset.select([p['id'] for p in entry['ctxs']])
        return question, answer, prompts['prompt_qa'], prompts['prompt_len'], entry['test_label']
