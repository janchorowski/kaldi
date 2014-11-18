#!/bin/bash

# Copyright 2013   (Authors: Bagher BabaAli, Daniel Povey, Arnab Ghoshal)
#           2014   Brno University of Technology (Author: Karel Vesely)
#           2014   Jan Chorowski
# Apache 2.0.

function error_exit () {
echo -e "$@" >&2; exit 1;
}

if [ $# -ne 1 ]; then
   echo "Argument should be the Corpora directory, see ../run.sh for example."
   exit 1;
fi

dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils
conf=`pwd`/conf

. ./path.sh # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi

[ -f $conf/test_spk.list ] || error_exit "$PROG: Eval-set speaker list not found.";
[ -f $conf/dev_spk.list ] || error_exit "$PROG: dev-set speaker list not found.";
[ -f $conf/train_spk.list ] || error_exit "$PROG: train-set speaker list not found.";

listed_speakers=`cat $conf/test_spk.list $conf/dev_spk.list $conf/train_spk.list | sort | uniq |wc -l`
found_speakers=`ls $* | wc -w`

[ $listed_speakers -eq $found_speakers ] || error_exit "$PROG: given speaker lists differ from the found speakers"

tmpdir=$(mktemp -d);
trap 'rm -rf "$tmpdir"' EXIT

cd $dir
for x in train dev test; do
  # First, find the list of audio files (use only si & sx utterances).
  # Note: train & test sets are under different directories, but doing find on 
  # both and grepping for the speakers will work correctly.
  find $* -iname '*.WAV' \
    | grep -f $conf/${x}_spk.list > ${x}_sph.flist

  sed -e 's:.*/\(.*\).WAV$:\1:i' ${x}_sph.flist \
    > $tmpdir/${x}_sph.uttids
  paste $tmpdir/${x}_sph.uttids ${x}_sph.flist \
    | sort -k1,1 > ${x}_sph.scp

  cat ${x}_sph.scp | awk '{print $1}' > ${x}.uttids

  # Now, Convert the transcripts into our format (no normalization yet)
  # Get the transcripts: each line of the output contains an utterance 
  # ID followed by the transcript.
  
  for mlf_file in `find $* -iname '*.mlf' \
      | grep -f $conf/${x}_spk.list`;
  do
      python $local/mlf_to_text.py $mlf_file
  done | sort -k1,1 > ${x}.text
  
  # Create wav.scp
  awk '{printf("%s sox %s -t wav - |\n", $1, $2);}' < ${x}_sph.scp > ${x}_wav.scp

  # Make the utt2spk and spk2utt files.
  cut -c-5  $x.uttids | paste -d' ' $x.uttids - > $x.utt2spk 
  cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;

  # Prepare gender mapping
  cat $x.spk2utt | awk 'BEGIN {map["c"]=map["m"]="m"; map["d"]=map["k"]="f";}\
                        {print $1 " " map[substr($1,4,1)]}' > $x.spk2gender

  # Prepare STM file for sclite:
  wav-to-duration scp:${x}_wav.scp ark,t:${x}_dur.ark || exit 1
  awk -v dur=${x}_dur.ark \
  'BEGIN{ 
     while(getline < dur) { durH[$1]=$2; } 
     print ";; LABEL \"O\" \"Overall\" \"Overall\"";
     print ";; LABEL \"F\" \"Female\" \"Female speakers\"";
     print ";; LABEL \"M\" \"Male\" \"Male speakers\""; 
     map["c"]=map["m"]="m"; map["d"]=map["k"]="f";
   } 
   { wav=$1; spk=substr(wav,0,5); $1=""; ref=$0;
     gender=(map[substr(spk,4,1)]);
     printf("%s 1 %s 0.0 %f <O,%s> %s\n", wav, spk, durH[wav], gender, ref);
   }
  ' ${x}.text >${x}.stm || exit 1

  # Create dummy GLM file for sclite:
  echo ';; empty.glm
  [FAKE]     =>  %HESITATION     / [ ] __ [ ] ;; hesitation token
  ' > ${x}.glm
done

echo "Data preparation succeeded"
