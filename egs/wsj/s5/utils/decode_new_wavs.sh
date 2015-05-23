#!/bin/bash


cmd=utils/run.pl
nj=1

min_lmwt=0
max_lmwt=10

decode_cmd=steps/decode.sh

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 2 ]; then
   echo "Usage: $0 [options] <wav-dir> <model-dir>";
   echo "e.g.: $0 new_wav exp/mono"
   exit 1;
fi

dir=$1
src_dir=$2

decode_dir=$dir/decode_`basename $src_dir`

utils/compute_mfcc_new_wavs.sh

$decode_cmd --nj $nj --cmd "$cmd" \
    --srcdir $src_dir \
    --skip_scoring true \
    $src_dir/graph $dir $decode_dir

for LMWT in `seq $min_lmwt $max_lmwt`; do
    lattice-best-path --lm-scale=$LMWT \
	ark:"gunzip -c $decode_dir/lat.1.gz |" ark,t:- ark:/dev/null | \
	utils/int2sym.pl -f 2- data/lang/words.txt > ${decode_dir}.$LMWT.txt
    

    if [ -d ${decode_dir}.si ]
    then 
	
	lattice-best-path --lm-scale=$LMWT \
	    ark:"gunzip -c ${decode_dir}.si/lat.1.gz |" ark,t:- ark:/dev/null | \
	    utils/int2sym.pl -f 2- data/lang/words.txt > ${decode_dir}.si.$LMWT.txt
    fi
done
