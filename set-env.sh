#!/bin/bash

export KALDI_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export KALDI_PYTHON=$KALDI_ROOT/kaldi-python

#path for Kaldi
export PATH=$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/irstlm/bin/:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/kwsbin:$KALDI_PYTHON/scripts:$PATH
export PYTHONPATH=$KALDI_PYTHON/kaldi-python:$PYTHONPATH

#export LC_ALL=C
export IRSTLM=$KALDI_ROOT/tools/irstlm
