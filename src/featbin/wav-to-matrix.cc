// featbin/wav-copy.cc

// Copyright 2013-2014  Daniel Povey

// See ../../COPYING for clarification regarding multiple authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "feat/feature-mfcc.h"
#include "feat/wave-reader.h"
#include "matrix/kaldi-matrix.h"

int main(int argc, char *argv[]) {
  try {
    using namespace kaldi;
    const char *usage =
        "Copy archives of wave files as matrices\n"
        "\n"
    	"The resulting matrices will be of shape num_samples x num_channels"
        "Usage:  wav-to-matrix [options...] <wav-rspecifier> <matrix-rspecifier>\n"
        "e.g. wav-matrix scp:wav.scp ark:-\n"
        "See also: wav-to-duration extract-segments\n";
    
    ParseOptions po(usage);

    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string wav_rspecifier = po.GetArg(1),
    		matrix_out_fn = po.GetArg(2);

    int32 num_done = 0;
    
    SequentialTableReader<WaveHolder> wav_reader(wav_rspecifier);
    BaseFloatMatrixWriter matrix_writer(matrix_out_fn);

    for (; !wav_reader.Done(); wav_reader.Next()) {
      Matrix<BaseFloat> m(wav_reader.Value().Data());
      m.Transpose();
      matrix_writer.Write(wav_reader.Key(), m);
      num_done++;
    }
    KALDI_LOG << "Copied " << num_done << " wave files";
    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}

