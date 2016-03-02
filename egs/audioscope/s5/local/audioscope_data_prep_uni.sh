#!/bin/bash

set -e
#set -x

# Copyright 2013   (Authors: Bagher BabaAli, Daniel Povey, Arnab Ghoshal)
#           2014   Brno University of Technology (Author: Karel Vesely)
#           2014   Jan Chorowski
#           2015   Michal Barcis
#           2015   Pawel Florczuk
# Apache 2.0.

function error_exit () {
echo -e "$@" >&2; exit 1;
}

if [ $# -ne 4 ]; then
   echo "Arguments should be the Audioscope, Audiobooki, Eksperci1 and Eksperci2 directories, see ../run.sh for example."
   exit 1;
fi

dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils
conf=`pwd`/conf
datadir=`pwd`/data

audioscope=$1
audiobooks=$2
dev_set=$3
test_set=$4

. ./path.sh # Needed for KALDI_ROOT

tmpdir=$(mktemp -d);
#tmpdir=/pio/scratch/1/i246062/poligon/tmp_debug
trap 'rm -rf "$tmpdir"' EXIT

train_data_dir=./conf/max1h100

#### Balance speakers from files list.

cat $train_data_dir/train_audiobooks.fileids | \
  sed -e "s:max1hSimple/\(.*\)/\(.*\):max1hSimple/\1__\2 sox $audiobooks/\1/\2.wav -t wav - |:" | \
  sort | wav-to-duration scp:- ark,t:- > $tmpdir/train_audiobooks_dur.ark

python $train_data_dir/balance_train_data.py $tmpdir/train_audiobooks_dur.ark 60.0 5 \
  | sort > $tmpdir/train_audiobooks_balanced.fileids

#### Generate transcriptions for balanced speakers

cat $tmpdir/train_audiobooks_balanced.fileids | sed "s:max1hSimple/\(.*\)__\(.*\):\1.txt:g" > $tmpdir/train_audiobooks.txtfileids

for x in `cat $tmpdir/train_audiobooks.txtfileids | sed "s:^:$audiobooks/:g"`
do
    echo -n "<s> "
    cat $x
    echo -n " </s>"
    echo
done > $tmpdir/train_audiobooks_text.txt

cat $tmpdir/train_audiobooks_balanced.fileids | sed "s:max1hSimple/.*/\(.*\):(\1):g" > $tmpdir/train_audiobooks_uttids.txt

paste -d" " $tmpdir/train_audiobooks_text.txt $tmpdir/train_audiobooks_uttids.txt > $tmpdir/train_audiobooks.transcription

#### Join audiobooks, corpora and snuv

cat $train_data_dir/corpora.fileids > $tmpdir/train_all.fileids
cat $train_data_dir/snuv.fileids >> $tmpdir/train_all.fileids
cat $tmpdir/train_audiobooks_balanced.fileids >> $tmpdir/train_all.fileids

cat $train_data_dir/corpora.transcription > $tmpdir/train_all.transcription
cat $train_data_dir/snuv.transcription >> $tmpdir/train_all.transcription
cat $tmpdir/train_audiobooks.transcription >> $tmpdir/train_all.transcription

#### Generate wav.scp

cat $tmpdir/train_all.fileids | grep 'corpora\|snuv' |\
    sed -e "s:\(.*/\(.*\)/\(.*\)\):\3 \2__\3 sox $audioscope/voice/\1.wav -t wav - |:" > $tmpdir/train_wav.scp

cat $tmpdir/train_all.fileids | grep 'max1hSimple' |\
    sed -e "s:max1hSimple/\(\(.*\)-.*/\(.*\)\)__\(.*\):\3__\4 \2__\3__\4 sox $audiobooks/\1.wav -t wav - |:" >> $tmpdir/train_wav.scp

cat $tmpdir/train_wav.scp | cut -d ' ' -f 2- | sort > $dir/train_wav.scp
cat $tmpdir/train_wav.scp | cut -d ' ' -f 1-2 | sort > $dir/train_sphinx_kaldi_uttid

#### Create phoneme and word based text for each utterance

cat $tmpdir/train_all.transcription | \
    sed -e 's/\(.* (\(.*\))\)/\2 \1/' | \
    sed -e 's/<s>//' -e 's:</s> (.*)::' > $tmpdir/train_transcripts.tmp

cat $tmpdir/train_transcripts.tmp | \
    ./local/gen_transcripts.py --expect-uttid=True --split-sil="<sil>" ${audioscope}/voice/saySentence/ | \
    sed -e 's/<sil>/sil/g' | \
    sort > $tmpdir/train_phones.text

#cat $tmpdir/train_transcripts.tmp | \
#    sed 's/<sil>//g' | \
#    ./local/gen_transcripts.py --expect-uttid=True --split-sil=" " ${audioscope}/voice/saySentence/ | \
#    sed -e 's/<sil>/sil/g' | \
#    sort > $tmpdir/train_phones.text

cat $tmpdir/train_transcripts.tmp | \
    sed -e 's/<sil>/sil/g' | \
    sort > $tmpdir/train_words.text

join $dir/train_sphinx_kaldi_uttid $tmpdir/train_phones.text | cut -d' ' -f 2- | sort > $dir/train_phones.text
join $dir/train_sphinx_kaldi_uttid $tmpdir/train_words.text | cut -d' ' -f 2- | sort > $dir/train_words.text

#### Dev (valdiation) set

cat $dev_set/eksperci/wav.scp | sort > $dir/dev_wav.scp
cat $dev_set/eksperci/text | sort > $dir/dev_phones.text
cat $dev_set/prompts.txt.tmp | sort > $dir/dev_words.text
cat $dev_set/eksperci/utt2spk | sort > $dir/dev.utt2spk
#cut -d ' ' -f 1 $dev_set/eksperci/utt2spk > $tmpdir/uttofspk_dev.text
#paste -d ' ' $tmpdir/uttofspk_dev.text $tmpdir/uttofspk_dev.text | sort > $dir/dev.utt2spk

#### Test set

cat $test_set/wav.scp | sort > $dir/test_wav.scp
cat $test_set/text_phones | sort > $dir/test_phones.text
cat $test_set/text_words | sort > $dir/test_words.text
cat $test_set/utt2spk | sort > $dir/test.utt2spk
#cut -d ' ' -f 1 $test_set/utt2spk > $tmpdir/uttofspk_test.text
#paste -d ' ' $tmpdir/uttofspk_test.text $tmpdir/uttofspk_test.text | sort > $dir/test.utt2spk

cd $dir
for x in train dev test; do
  cat ${x}_wav.scp | awk '{print $1}' > ${x}.uttids

  # Make the utt2spk and spk2utt files for train. Dev and test are copied above.
  if [ $x == "train" ]; then
      cat $x.uttids | perl -pe 's/((.*?)__.*)/\1 \2/' > $x.utt2spk
  fi
  cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;

  # Prepare gender mapping
  # Do we ever need this??
  # cat $x.spk2utt | awk 'BEGIN {map["c"]=map["m"]="m"; map["d"]=map["k"]="f";}\
  #                       {print $1 " " map[substr($1,4,1)]}' > $x.spk2gender

  # # Prepare STM file for sclite:
  # we will only compute durations.
  wav-to-duration scp:${x}_wav.scp ark,t:${x}_dur.ark || exit 1
done

if [ ! -f $datadir/lm_suffixes.sh ]; then
  echo "export LM_SUFFIXES=(\"bg\")" > $datadir/lm_suffixes.sh
fi

if [ ! -L $datadir/lang ]; then
  ln -s lang_test_bg $datadir/lang
fi

echo "Data preparation succeeded"
