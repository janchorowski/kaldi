#!/bin/bash

# Copyright 2013   (Authors: Bagher BabaAli, Daniel Povey, Arnab Ghoshal)
#           2014   Brno University of Technology (Author: Karel Vesely)
#           2014   Jan Chorowski
# Apache 2.0.

function error_exit () {
echo -e "$@" >&2; exit 1;
}

if [ $# -ne 1 ]; then
   echo "Argument should be the Audioscope directory, see ../run.sh for example."
   exit 1;
fi

dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils
conf=`pwd`/conf

audioscope=$1

. ./path.sh # Needed for KALDI_ROOT

[ -f $conf/test_books.list ] || error_exit "$PROG: Eval-set book list not found.";
[ -f $conf/dev_books.list ] || error_exit "$PROG: dev-set book list not found.";
[ -f $conf/train_books.list ] || error_exit "$PROG: train-set book list not found.";

listed_books=`cat $conf/test_books.list $conf/dev_books.list $conf/train_books.list | sort | uniq |wc -l`
found_books=`ls $audioscope/voice/audiobooks | wc -w`

[ $listed_books -eq $found_books ] || error_exit "$PROG: given books lists differ from the found books"

tmpdir=$(mktemp -d);
trap 'rm -rf "$tmpdir"' EXIT

cd $dir
for x in train dev test; do
  # First, find the list of audio files (use only si & sx utterances).
  # Note: train & test sets are under different directories, but doing find on 
  # both and grepping for the speakers will work correctly.
  find ${audioscope} -iname '*.WAV' \
    | grep -f $conf/${x}_books.list > ${x}_wav.flist

  sed -e 's:.*/\(.*\)-.*/\(.*\).WAV$:\1__\2:i' ${x}_wav.flist \
    > $tmpdir/${x}_wav.uttids
  paste $tmpdir/${x}_wav.uttids ${x}_wav.flist \
    | sort -k1,1 > ${x}_wav.scp

  cat ${x}_wav.scp | awk '{print $1}' > ${x}.uttids

  # Now, Convert the transcripts into our format (no normalization yet)
  # Get the transcripts: each line of the output contains an utterance 
  # ID followed by the transcript.
  
  for txt_file in `cat ${x}_wav.scp | cut -f 2 | sed -e 's/\.wav$/\.txt/i'`; 
  do 
      (cat "${txt_file}"; echo); 
  done | ../../../local/gen_transcripts.py ${audioscope}/voice/saySentence/ > $tmpdir/${x}.text
  
  paste -d" " ${x}.uttids $tmpdir/${x}.text > ${x}.text
  
  # Make the utt2spk and spk2utt files.
  cat $x.uttids | sed -e 's/\(.*\)__.*/\1/' | paste -d' ' $x.uttids - > $x.utt2spk 
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
