#!/bin/bash

# Copyright 2013   (Authors: Daniel Povey, Bagher BabaAli, Jan Chorowski)

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

[ -f path.sh ] && . ./path.sh

inputfile=$1
ngram=$2
outdir=$3
lm_suffix=$4

  [ -z "$IRSTLM" ] && \
    echo "LM building won't work without setting the IRSTLM env variable" && exit 1;
  ! which build-lm.sh 2>/dev/null  && \
    echo "IRSTLM does not seem to be installed (build-lm.sh not on your path): " && \
    echo "go to <kaldi-root>/tools and try 'make irstlm_tgt'" && exit 1;

cut -d' ' -f2- $inputfile | sed -e 's:^:<s> :' -e 's:$: </s>:' \
  > $outdir/lm_s_${lm_suffix}.text

build-lm.sh -i $outdir/lm_s_${lm_suffix}.text -n $ngram -o $outdir/lm_${lm_suffix}.ilm.gz

compile-lm $outdir/lm_${lm_suffix}.ilm.gz -t=yes /dev/stdout | \
  grep -v "<unk>" | gzip -c > $outdir/lm_${lm_suffix}.arpa.gz
