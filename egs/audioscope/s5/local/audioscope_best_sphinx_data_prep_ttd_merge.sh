#!/bin/bash

set -e
#set -x

# Copyright 2013   (Authors: Bagher BabaAli, Daniel Povey, Arnab Ghoshal)
#           2014   Brno University of Technology (Author: Karel Vesely)
#           2014   Jan Chorowski
# Apache 2.0.

function error_exit () {
echo -e "$@" >&2; exit 1;
}

if [ $# -ne 3 ]; then
   echo "Arguments should be the Audioscope, Eksperci and Audiobooki directories, see ../run.sh for example."
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
eksperci=$2
audiobooks=$3

. ./path.sh # Needed for KALDI_ROOT

#[ -f $conf/test_books.list ] || error_exit "$PROG: Eval-set book list not found.";
#[ -f $conf/dev_books.list ] || error_exit "$PROG: dev-set book list not found.";
#[ -f $conf/train_books.list ] || error_exit "$PROG: train-set book list not found.";

#listed_books=`cat $conf/test_books.list $conf/dev_books.list $conf/train_books.list | sort | uniq |wc -l`
#found_books=`ls $audioscope/voice/audiobooks | wc -w`

#[ $listed_books -eq $found_books ] || error_exit "$PROG: given books lists differ from the found books"

tmpdir=$(mktemp -d);
trap 'rm -rf "$tmpdir"' EXIT

best_sphinx=/pio/scratch/1/i246062/poligon/best_sphinx/all
best_files=$best_sphinx/an4_train

#### Generate filelists if there're no existing

if [ ! -f $best_sphinx/an4_train_audiobooks.fileids ]; then
  python3 $best_sphinx/generate_random_train_data.py $best_sphinx/an4_all_audiobooks.fileids > $tmpdir/an4_train_audiobooks.fileids

  ## In order to maintain a balance between multiple readers you can pass
  ## some recordings to Kaldi multiple times by appending different suffixes
  ## to the uttids. Below it is not done, only one parameter is added in order
  ## to maintain campatibility with the rest of the scripts.
  cat $tmpdir/an4_train_audiobooks.fileids | grep max1hSimple | sed "s:\(.*\):\1__0:g" > $best_sphinx/an4_train_audiobooks.fileids
fi

cat $best_sphinx/an4_train_audiobooks.fileids | sed "s:max1hSimple/\(.*\)__0:\1.txt:g" > $tmpdir/an4_train_audiobooks.txtfileids

for x in `cat $tmpdir/an4_train_audiobooks.txtfileids | sed "s:^:$audiobooks/:g"`
do
    echo -n "<s> "
    cat $x
    echo -n " </s>"
    echo
done > $tmpdir/an4_train_audiobooks.temp_transcription

cat $best_sphinx/an4_train_audiobooks.fileids | sed "s:max1hSimple/.*/\(.*\):(\1):g" > $tmpdir/an4_train_audiobooks.temp_fileids

paste -d" " $tmpdir/an4_train_audiobooks.temp_transcription $tmpdir/an4_train_audiobooks.temp_fileids > $best_sphinx/an4_train_audiobooks.transcription

#### Train files

cat $best_sphinx/an4_all_corpora.fileids > $best_sphinx/an4_train.fileids
cat $best_sphinx/an4_all_snuv.fileids >> $best_sphinx/an4_train.fileids
cat $best_sphinx/an4_train_audiobooks.fileids >> $best_sphinx/an4_train.fileids

cat $best_sphinx/an4_all_corpora.transcription > $best_sphinx/an4_train.transcription
cat $best_sphinx/an4_all_snuv.transcription >> $best_sphinx/an4_train.transcription
cat $best_sphinx/an4_train_audiobooks.transcription >> $best_sphinx/an4_train.transcription

cat ${best_files}.fileids | grep 'corpora\|snuv' |\
    sed -e "s:\(.*/\(.*\)/\(.*\)\):\3 \2__\3 sox $audioscope/voice/\1.wav -t wav - |:" > $tmpdir/train_wav.scp

cat ${best_files}.fileids | grep 'max1hSimple' |\
    sed -e "s:max1hSimple/\(\(.*\)-.*/\(.*\)\)__\(.*\):\3__\4 \2__\3__\4 sox $audiobooks/\1.wav -t wav - |:" >> $tmpdir/train_wav.scp

cat $tmpdir/train_wav.scp | cut -d ' ' -f 2- | sort > $dir/train_wav.scp
cat $tmpdir/train_wav.scp | cut -d ' ' -f 1-2 | sort > $dir/train_sphinx_kaldi_uttid

cat ${best_files}.transcription | \
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

# Commented because we don't want to get all files from $audiobooks directory

#cat $dir/train_wav.scp | sed -e 's:.* \(.*\.wav\).*:\1:' | sort | uniq | \
#    xargs -L1 readlink -f | \
#    sort | uniq > $dir/train_wav.flist

#### Dev files: all audio files not in train

#find ${audiobooks} -iname '*.WAV' | xargs -L1 readlink -f | \
#    sort | uniq > $dir/all_wav.flist

#comm -23 $dir/all_wav.flist $dir/train_wav.flist > $dir/dev_wav.flist

#cat $dir/dev_wav.flist | sed -e 's:\(.*/\(.*\)-.*/\(.*\).WAV$\):\2__\3 sox \1 -t wav - |:i' \
#    | sort -k1,1 > $dir/dev_wav.scp

cat $best_sphinx/an4_train.fileids | sort > $tmpdir/an4_train_sorted.fileids

comm -23 $best_sphinx/an4_all_audiobooks.fileids $tmpdir/an4_train_sorted.fileids |\
    grep max1hSimple | sed "s:\(.*\):\1__0:g" > $best_sphinx/an4_dev.fileids

cat $best_sphinx/an4_dev.fileids | grep 'max1hSimple' |\
    sed -e "s:max1hSimple/\(\(.*\)-.*/\(.*\)\)__\(.*\):\3__\4 \2__\3__\4 sox $audiobooks/\1.wav -t wav - |:" > $tmpdir/dev_wav.scp

cat $tmpdir/dev_wav.scp | cut -d ' ' -f 2- | sort > $dir/dev_wav.scp

# end of changes

for txt_file in `cat $dir/dev_wav.scp | sed -e 's:.* \(.*\.\)wav.*:\1txt:'`; do
    (cat "${txt_file}"; echo);
done > $tmpdir/dev_transcripts.tmp

cat $tmpdir/dev_transcripts.tmp | local/gen_transcripts.py ${audioscope}/voice/saySentence/ > $tmpdir/dev_phones.text

cat $dir/dev_wav.scp | cut -d ' ' -f 1 | paste -d' ' - $tmpdir/dev_phones.text > $dir/dev_phones.text
cat $dir/dev_wav.scp | cut -d ' ' -f 1 | paste -d' ' - $tmpdir/dev_transcripts.tmp > $dir/dev_words.text

##### Test files: eksperci

cat $eksperci/eksperci/wav.scp | sort > $dir/test_wav.scp
cat $eksperci/eksperci/text | sort > $dir/test_phones.text
cat $eksperci/prompts.txt.tmp | sort > $dir/test_words.text
cat $eksperci/eksperci/utt2spk | sort > $dir/test.utt2spk

cd $dir
for x in train dev test; do
  cat ${x}_wav.scp | awk '{print $1}' > ${x}.uttids

  # Make the utt2spk and spk2utt files for train and dev. Test is copied above.
  if [ ! $x == "test" ]; then
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
  echo "export LM_SUFFIXES=(\"bg\" \"train2gram\" \"dev2gram\" \"test2gram\")" > $datadir/lm_suffixes.sh
fi

if [ ! -L $datadir/lang ]; then
  ln -s lang_test_bg $datadir/lang
fi

echo "Data preparation succeeded"
