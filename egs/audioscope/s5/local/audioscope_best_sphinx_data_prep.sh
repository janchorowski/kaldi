#!/bin/bash

set -e

# Copyright 2013   (Authors: Bagher BabaAli, Daniel Povey, Arnab Ghoshal)
#           2014   Brno University of Technology (Author: Karel Vesely)
#           2014   Jan Chorowski
# Apache 2.0.

function error_exit () {
echo -e "$@" >&2; exit 1;
}

if [ $# -ne 2 ]; then
   echo "Arguments should be the Audioscope and Eksperci directories, see ../run.sh for example."
   exit 1;
fi

dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils
conf=`pwd`/conf

audioscope=$1
eksperci=$2

. ./path.sh # Needed for KALDI_ROOT

#[ -f $conf/test_books.list ] || error_exit "$PROG: Eval-set book list not found.";
#[ -f $conf/dev_books.list ] || error_exit "$PROG: dev-set book list not found.";
#[ -f $conf/train_books.list ] || error_exit "$PROG: train-set book list not found.";

#listed_books=`cat $conf/test_books.list $conf/dev_books.list $conf/train_books.list | sort | uniq |wc -l`
#found_books=`ls $audioscope/voice/audiobooks | wc -w`

#[ $listed_books -eq $found_books ] || error_exit "$PROG: given books lists differ from the found books"

tmpdir=$(mktemp -d);
trap 'rm -rf "$tmpdir"' EXIT

#### Train files

best_fileids=conf/best_sphinx/an4_train.fileids

cat $best_fileids | grep 'corpora\|snuv' |\
    sed -e "s:\(.*/\(.*\)/\(.*\)\):\3 \2__\3 sox $audioscope/voice/\1.wav -t wav - |:" > $tmpdir/train_wav.scp

cat $best_fileids | grep 'max1hSimple' |\
    sed -e "s:max1hSimple/\(\(.*\)-.*/\(.*\)\)__\(.*\):\3__\4 \2__\3__\4 sox $audioscope/voice/audiobooks/\1.wav -t wav - |:" >> $tmpdir/train_wav.scp

cat $tmpdir/train_wav.scp | cut -d ' ' -f 2- | sort > $dir/train_wav.scp
cat $tmpdir/train_wav.scp | cut -d ' ' -f 1-2 | sort > $dir/train_sphinx_kaldi_uttid

cat conf/best_sphinx/an4_train.transcription | \
    sed -e 's/\(.* (\(.*\))\)/\2 \1/' | \
    sed -e 's/<s>//' -e 's:</s> (.*)::' | \
    ./local/gen_transcripts.py --expect-uttid=True --split-sil="<sil>" ${audioscope}/voice/saySentence/ | \
    sed -e 's/<sil>/sil/g' | \
    sort > $tmpdir/train.text

join $dir/train_sphinx_kaldi_uttid $tmpdir/train.text | cut -d' ' -f 2- | sort > $dir/train.text

cat $dir/train_wav.scp | sed -e 's:.* \(.*\.wav\).*:\1:' | sort | uniq | \
    xargs -L1 readlink -f | \
    sort | uniq > $dir/train_wav.flist

#### Dev files: all audio files not in train

find ${audioscope}/voice/audiobooks -iname '*.WAV' | xargs -L1 readlink -f | \
    sort | uniq > $dir/all_wav.flist

comm -23 $dir/all_wav.flist $dir/train_wav.flist > $dir/dev_wav.flist

cat $dir/dev_wav.flist | sed -e 's:\(.*/\(.*\)-.*/\(.*\).WAV$\):\2__\3 sox \1 -t wav - |:i' \
    | sort -k1,1 > $dir/dev_wav.scp

for txt_file in `cat $dir/dev_wav.scp | sed -e 's:.* \(.*\.\)wav.*:\1txt:'`; do
    (cat "${txt_file}"; echo); 
done | local/gen_transcripts.py ${audioscope}/voice/saySentence/ > $tmpdir/dev.text
  
cat $dir/dev_wav.scp | cut -d ' ' -f 1 | paste - $tmpdir/dev.text > $dir/dev.text

##### Test files: eksperci

cat $eksperci/eksperci/wav.scp | sort > $dir/test_wav.scp
cat $eksperci/eksperci/text | sort > $dir/test.text
cat $eksperci/eksperci/utt2spk | sort > $dir/test.utt2spk

cd $dir
for x in train dev test; do
  cat ${x}_wav.scp | awk '{print $1}' > ${x}.uttids
  
  # Make the utt2spk and spk2utt files.
  if [ ! -f $x.utt2spk ]; then
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

echo "Data preparation succeeded"
