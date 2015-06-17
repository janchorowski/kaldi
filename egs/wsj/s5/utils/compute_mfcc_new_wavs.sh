#!/bin/bash

cmd=utils/run.pl
nj=1

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "Usage: $0 [options] <wav-dir>";
   echo "e.g.: $0 new_wav"
   exit 1;
fi

dir=$1

mkdir -p $dir

if [ ! -f $dir/spk2utt ]; then
    if [ -f $dir/utt2spk ]; then
	utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt
    fi
fi

if [ ! -f $dir/utt2spk ]; then
    if [ -f $dir/spk2utt ]; then
	utils/spk2utt_to_utt2spk.pl $dir/spk2utt > $dir/utt2spk
    fi
fi

if [ ! -f $dir/spk2utt ]; then
    >&2 echo "Generating spk2utt and utt2spk"
    cat $dir/wav.scp | cut -d' ' -f1 > $dir/utt_ids
    paste -d' ' $dir/utt_ids $dir/utt_ids  > $dir/spk2utt
    cp $dir/spk2utt $dir/utt2spk
else
    >&2 echo "Not generating spk2utt and utt2spk since they are already there"
fi

cat conf/mfcc.conf $dir/conf/mfcc.conf 2>/dev/null > $dir/mfcc.conf

if ! [ -f $dir/mfcc/cmvn_decode.scp ]
then 
    steps/make_mfcc.sh --mfcc-config $dir/mfcc.conf --nj "$nj" --cmd "$cmd" $dir $dir/log/mfcc $dir/mfcc
    steps/compute_cmvn_stats.sh $dir $dir/log/cmvn $dir/mfcc
else
    echo "Skipping mfcc computation"
fi
