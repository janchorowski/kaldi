#!/bin/bash

x=data/test2
cmd=utils/run.pl
nj=1

lmwt=3
mbr_scale=1.0

steps/make_mfcc.sh --nj "$nj" --cmd "$cmd" $x $x/log/mfcc $x/mfcc
steps/compute_cmvn_stats.sh $x $x/log/cmvn $x/mfcc

steps/decode.sh --nj $nj --cmd "$cmd" \
 --srcdir exp/mono \
 --skip_scoring true \
 exp/mono/graph $x $x/decode_mono

lattice-best-path --acoustic-scale=$(bc <<<"scale=8; 1/$lmwt*$mbr_scale") --lm-scale=$mbr_scale \
   ark:"gunzip -c $x/decode_mono/lat.1.gz |" ark,t:- ark:/dev/null | \
   utils/int2sym.pl -f 2- data/lang/words.txt > $x/decoded_mono.txt


steps/decode_fmllr.sh --nj "$nj" --cmd "$cmd" \
 --srcdir exp/tri3 \
 --skip_scoring true \
 exp/tri3/graph $x $x/decode_tri3

lattice-best-path --acoustic-scale=$(bc <<<"scale=8; 1/$lmwt*$mbr_scale") --lm-scale=$mbr_scale \
   ark:"gunzip -c $x/decode_tri3.si/lat.1.gz |" ark,t:- ark:/dev/null | \
   utils/int2sym.pl -f 2- data/lang/words.txt > $x/decoded_tri3.si.txt


lattice-best-path --acoustic-scale=$(bc <<<"scale=8; 1/$lmwt*$mbr_scale") --lm-scale=$mbr_scale \
   ark:"gunzip -c $x/decode_tri3/lat.1.gz |" ark,t:- ark:/dev/null | \
   utils/int2sym.pl -f 2- data/lang/words.txt > $x/decoded_tri3.txt
