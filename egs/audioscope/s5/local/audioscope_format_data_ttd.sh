#!/bin/bash

# Copyright 2013  (Author: Daniel Povey)
# Apache 2.0

# This script takes data prepared in a corpus-dependent way
# in data/local/, and converts it into the "canonical" form,
# in various subdirectories of data/, e.g. data/lang, data/train, etc.

. ./path.sh || exit 1;

echo "Preparing train, dev and test data"
srcdir=data/local/data
lmdir=data/local/nist_lm
tmpdir=data/local/lm_tmp
lexicon=data/local/dict/lexicon.txt
mkdir -p $tmpdir

for x in train dev test; do
  for y in phones words; do
    mkdir -p data/${x}_${y}
    cp $srcdir/${x}_wav.scp data/${x}_${y}/wav.scp || exit 1;
    cp $srcdir/${x}_${y}.text data/${x}_${y}/text || exit 1;
    cp $srcdir/$x.spk2utt data/${x}_${y}/spk2utt || exit 1;
    cp $srcdir/$x.utt2spk data/${x}_${y}/utt2spk || exit 1;
    #utils/filter_scp.pl data/$x/spk2utt $srcdir/$x.spk2gender > data/$x/spk2gender || exit 1;
    #cp $srcdir/${x}.stm data/$x/stm
    #cp $srcdir/${x}.glm data/$x/glm
    utils/validate_data_dir.sh --no-feats data/${x}_${y} || exit 1
  done
done

# Next, for each type of language model, create the corresponding FST
# and the corresponding lang_test_* directory.

echo Preparing language models for test

# Get list of lm suffixes

source data/lm_suffixes.sh

for lm_suffix in "${LM_SUFFIXES[@]}"
do
  test=data/lang_test_${lm_suffix}

  gunzip -c $lmdir/lm_phone_${lm_suffix}.arpa.gz | \
    utils/find_arpa_oovs.pl $test/words.txt > $tmpdir/oovs_${lm_suffix}.txt

  gunzip -c $lmdir/lm_phone_${lm_suffix}.arpa.gz | \
    egrep -v '<s> <s>|</s> <s>|</s> </s>' | \
    arpa2fst - | fstprint | \
    utils/remove_oovs.pl $tmpdir/oovs_${lm_suffix}.txt | \
    utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$test/words.txt \
     --osymbols=$test/words.txt  --keep_isymbols=false --keep_osymbols=false | \
    fstrmepsilon | fstarcsort --sort_type=ilabel > $test/G.fst
  fstisstochastic $test/G.fst
 # The output is like:
 # 9.14233e-05 -0.259833
 # we do expect the first of these 2 numbers to be close to zero (the second is
 # nonzero because the backoff weights make the states sum to >1).
 # Because of the <s> fiasco for these particular LMs, the first number is not
 # as close to zero as it could be.

 # Everything below is only for diagnostic.
 # Checking that G has no cycles with empty words on them (e.g. <s>, </s>);
 # this might cause determinization failure of CLG.
 # #0 is treated as an empty word.
  mkdir -p $tmpdir/g
  awk '{if(NF==1){ printf("0 0 %s %s\n", $1,$1); }} END{print "0 0 #0 #0"; print "0";}' \
    < "$lexicon"  >$tmpdir/g/select_empty.fst.txt
  fstcompile --isymbols=$test/words.txt --osymbols=$test/words.txt $tmpdir/g/select_empty.fst.txt | \
   fstarcsort --sort_type=olabel | fstcompose - $test/G.fst > $tmpdir/g/empty_words.fst
  fstinfo $tmpdir/g/empty_words.fst | grep cyclic | grep -w 'y' && 
    echo "Language model has cycles with empty words" && exit 1
  rm -r $tmpdir/g
done

utils/validate_lang.pl data/lang_test_bg || exit 1

echo "Succeeded in formatting data."
rm -r $tmpdir
