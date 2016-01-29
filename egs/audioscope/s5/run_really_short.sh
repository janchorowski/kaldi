#!/bin/bash

#
# Copyright 2013 Bagher BabaAli,
#           2014 Brno University of Technology (Author: Karel Vesely)
#           2014 Jan Chorowski
#
# Audioscope: a database of Polish audiobooks.
#

#
# Run on the best file selection from SPhinx
#
#


. ./cmd.sh
[ -f path.sh ] && . ./path.sh
set -e
#set -x

# Acoustic model parameters
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=16
train_nj=16
decode_nj=2

echo ============================================================================
echo "                Data & Lexicon & Language Preparation                     "
echo ============================================================================

audioscope=/pio/data/data/audioscope
eksperci=/home/jch/scratch/korpusiki/eksperci
modele=/pio/scratch/1/i246062/l_models/test_models
audiobooks=/pio/data/data/audioscope/voice/audiobooks/all

local/audioscope_data_prep_uni.sh $audioscope $eksperci $audiobooks || exit 1

# Get lm suffixes
source data/lm_suffixes.sh

local/audioscope_prepare_dict_ultimate.sh $modele

# Insert optional-silence with probability 0.5, which is the
# default.
for lm_suffix in "${LM_SUFFIXES[@]}"
do
  utils/prepare_lang.sh --position-dependent-phones false --num-sil-states 3 \
   data/local/dict/dict_${lm_suffix} "sil" data/local/lang_tmp_${lm_suffix} \
   data/lang_test_${lm_suffix}
done

local/audioscope_format_data_ttd.sh

echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training and Test set           "
echo ============================================================================

# Now make MFCC features.
mfccdir=mfcc


for x in train dev test; do
  for y in phones words; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $feats_nj data/${x}_${y} exp/make_mfcc/${x}_${y} $mfccdir
    steps/compute_cmvn_stats.sh data/${x}_${y} exp/make_mfcc/${x}_${y} $mfccdir
  done
done

echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================

steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data/train_phones data/lang exp/mono

for lm_suffix in "${LM_SUFFIXES[@]}"
do
  echo " -- For LM: $lm_suffix..."

  if [ $lm_suffix == "bg" ]; then
    ttd_suffix="phones"
  else
    ttd_suffix="words"
  fi

  utils/mkgraph.sh --mono data/lang_test_${lm_suffix} exp/mono exp/mono/graph_${lm_suffix}

  steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
   exp/mono/graph_${lm_suffix} data/dev_${ttd_suffix} exp/mono/decode_dev_${lm_suffix}

  steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
   exp/mono/graph_${lm_suffix} data/test_${ttd_suffix} exp/mono/decode_test_${lm_suffix}
done

echo ============================================================================
echo "                    Getting Results [see RESULTS file]                    "
echo ============================================================================

bash RESULTS dev
bash RESULTS test

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0
