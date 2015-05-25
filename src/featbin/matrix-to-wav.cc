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
        "Create wavs from matrices\n"
        "\n"
    	"The resulting matrices will be of shape num_samples x num_channels"
        "Usage:  matrix-to-wav [options...] <wav-rspecifier> <matrix-rspecifier>\n"
        "e.g. matrix-to-wav --sample-frequency=16000 scp:matrix.scp ark:-\n"
        "See also: wav-to-matrix wav-to-duration extract-segments\n";
    
    ParseOptions po(usage);

    BaseFloat samp_freq = 16000;

    po.Register("sample-frequency", &samp_freq, "Waveform data sample frequency");

    po.Read(argc, argv);

    if (po.NumArgs() != 2) {
      po.PrintUsage();
      exit(1);
    }

    std::string matrix_rspecifier = po.GetArg(1),
    			wav_wspecifier = po.GetArg(2);

    int32 num_done = 0;
    
    SequentialBaseFloatMatrixReader matrix_reader(matrix_rspecifier);
    TableWriter<WaveHolder> wav_writer(wav_wspecifier);

    for (; !matrix_reader.Done(); matrix_reader.Next()) {
      Matrix<BaseFloat> m(matrix_reader.Value());
      m.Transpose();
      WaveData wav = WaveData(samp_freq, m);
      wav_writer.Write(matrix_reader.Key(), wav);
      num_done++;
    }
    KALDI_LOG << "Copied " << num_done << " wave files";
    return (num_done != 0 ? 0 : 1);
  } catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}

