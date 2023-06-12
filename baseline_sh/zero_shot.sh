export LD_LIBRARY_PATH=/nvme/xnli/anaconda3/envs/lk_epr/lib:$LD_LIBRARY_PATH
export http_proxy=http://pjlab:pjlab321@10.1.52.47:3333
export https_proxy=http://pjlab:pjlab321@10.1.52.47:3333
cvd=0,1,2,3
num_gpus=4
exp_name="zero_shot_1224"
cls_test_datasets=("agnews" "amazon" "cola" "copa" "cosmos_qa" "cr" "cs_explan" "cs_valid" "dbpedia" "mr" "snli" "sst2" \
"sst5" "subj" "trec" "yahoo" "yelp_full")
cls_valid_datasets=("mnli" "qnli" "rte" "wnli")
gen_test_datasets=("mtop" "cnndailymail" "dart" "e2e" "go" "java" "javascript" "php" "pubmed" "python" "reddit" \
"roc_ending_generation" "roc_story_generation")
gen_valid_datasets=("break" "common_gen" "smcalflow")

main_process_port=23100
num_prompts=-1

mkdir -p "$PWD/exps/$exp_name/ctx_data"
mkdir -p "$PWD/exps/$exp_name/inf_data"

for ds in "${gen_valid_datasets[*]}" "${gen_test_datasets[*]}" "${cls_valid_datasets[*]}" "${cls_test_datasets[*]}" "wikiauto"; do

if [[ ${ds} == "${cls_valid_datasets[*]}" ]]; then
  echo "cls valid datasets"
  splits=("validation")
  gen=False
  num_prompts=8
  inf_bs=15
elif [[ ${ds} == "${cls_test_datasets[*]}" ]]; then
  echo "cls test datasets"
  splits=("test")
  gen=False
  num_prompts=8
  inf_bs=15
elif [[ ${ds} == "${gen_valid_datasets[*]}" ]]; then
  echo "gen valid datasets"
  splits=("validation")
  gen=True
  num_prompts=-1
  inf_bs=8
elif [[ ${ds} == "${gen_test_datasets[*]}" ]]; then
  echo "gen test datasets"
  splits=("test")
  gen=True
  num_prompts=-1
  inf_bs=8
elif [[ ${ds} == "wikiauto" ]]; then
  echo "wikiauto test"
  splits=("test_asset" "test_turk" "test_wiki")
  gen=True
  num_prompts=-1
  inf_bs=8
fi

datasets=(${ds})
for dataset in "${datasets[@]}"; do
  for split in "${splits[@]}"; do
    ctxs_fp="$PWD/exps/$exp_name/ctx_data/zero_shot_${dataset}_${split}.json"
    if [ ! -f "$ctxs_fp" ]; then
      echo "generating contexts for $dataset $split"
      python baseline/get_zero_shot_ctxs.py \
        --dataset "$dataset" \
        --split "$split" \
        --out_fp "$ctxs_fp"
    fi

    echo -e "bash run \n accelerate launch inference.py --split $split"

    inference_out="$PWD/exps/$exp_name/inf_data/inf_${dataset}_${split}_${num_prompts}prompts.json"
    if [ ! -f "$inference_out" ]; then
    CUDA_VISIBLE_DEVICES=$cvd \
    TOKENIZERS_PARALLELISM=false \
    HYDRA_FULL_ERROR=1 \
    accelerate launch --num_processes $num_gpus --main_process_port ${main_process_port} --multi_gpu\
         inference.py \
         prompt_file="${ctxs_fp}" \
         task_name=$dataset \
         output_file="$inference_out" \
         gen="${gen}" \
         num_prompts=${num_prompts} \
         batch_size=${inf_bs} max_length=1950 \
         hydra.run.dir="$PWD/exps/$exp_name/logs"
    fi

    echo -e "bash run \n python tmp_test.py --split $split"
    if [ "${gen}" = "True" ]; then
    python tmp_test.py --fp "${inference_out}" --dataset $dataset --split $split \
    --exp_name ${exp_name} --iter_num -1 --epoch_num -1 --method "zero_shot" \
    --prompt_num ${num_prompts}
    else
    python cls_test.py --fp "${inference_out}" --dataset $dataset --split $split \
    --exp_name ${exp_name} --iter_num -1 --epoch_num -1 --method "zero_shot" \
    --prompt_num ${num_prompts}
    fi
    done
  done
done
