#!/usr/bin/env python

import numpy as np

import logging
logger = logging.getLogger(__file__)

import kaldi_io
import kaldi_argparse

def get_parser():
    parser = kaldi_argparse.KaldiArgumentParser(description="Discard silent frames")
    parser.add_argument('feat_rx', help='Feature reader')
    parser.add_argument('feat_wx', help='Feature writer')
    parser.add_argument('selection_wx', default=None, help='Selected frames writer',
                        nargs='?')
    
    parser.add_argument('--vad-energy-mean-scale', default=0.5, type=float, help="If this is set to s, to get the actual threshold we let m be the mean log-energy of the file, and use s*m + vad-energy-threshold")
    parser.add_argument('--vad-energy-threshold', default=5, type=float, help='Constant term in energy threshold for MFCC0 for VAD (also see --vad-energy-mean-scale)')
    parser.add_argument('--vad-frames-context', default=5, type=int, help='Number of frames of context on each side of central frame, in window for which energy is monitored')
    parser.add_argument('--vad-proportion-threshold', default=0.6, type=float, help='Parameter controlling the proportion of frames within the window that need to have more energy than the threshold')
    
    parser.add_argument('--min-silence-duration', default=0, type=int, help="Minimum number of silent frames to treat as no activity")
    parser.add_argument('--energy-mean-window', default=500, type=int, help="Number of frames of context on each side to compute the mean energy")
    parser.add_argument('--silence-reduction', default=0, type=int, help="Number of frames to shrink silenece regions on each side. Negative values enlarge silent regions")
    
    parser.add_standard_arguments()
    return parser

def contiguous_regions(condition):
    """Finds contiguous True regions of the boolean array "condition". Returns
    a 2D array where the first column is the start index of the region and the
    second column is the end index."""

    # Find the indicies of changes in "condition"
    d = np.diff(condition)
    idx, = d.nonzero() 

    # We need to start things after the change in "condition". Therefore, 
    # we'll shift the index by 1 to the right.
    idx += 1

    if condition[0]:
        # If the start of condition is True prepend a 0
        idx = np.r_[0, idx]

    if condition[-1]:
        # If the end of condition is True, append the length of the array
        idx = np.r_[idx, condition.size] # Edit

    # Reshape the result into two columns
    idx.shape = (-1,2)
    return idx

def select_feats(feats, opts, out=None):
    e = feats[:,0] #energy
    
    e_win=opts.energy_mean_window 
    if feats.shape[0] < e_win:
        e_mean = e.mean()
    else:
        e_padded = np.hstack([e[e_win::-1], e, e[:-e_win:-1]])
        e_mean = np.convolve(e_padded, np.ones(2*e_win+1)/(2.0*e_win+1.0), 'valid')
    threshold = e_mean * opts.vad_energy_mean_scale + opts.vad_energy_threshold
    
    c = (e > threshold) #vad Candidates
    
    c_win = 2*opts.vad_frames_context + 1
    c = np.convolve(c, np.ones(c_win),'same') > c_win*opts.vad_proportion_threshold
    
    s_regions = contiguous_regions(1 - c) #silence regions
    s_regions = s_regions[(s_regions[:,1]-s_regions[:,0])>(opts.min_silence_duration-1), :]
    
    if s_regions[0,0]==0: #prevent inserting non-slience at the beginning!
        s_regions[0,0] -= opts.silence_reduction
    #shrink each silence region
    s_regions[:,0] += opts.silence_reduction
    
    if s_regions[-1,1] == e.shape[0]-1: #shrink silence ends making sure that we do not shift the first one
        s_regions[-1,1] += opts.silence_reduction
    s_regions[:,1] -= opts.silence_reduction
    
    if out is None:
        selection=np.ones(feats.shape[0], dtype=np.bool)
    else:
        selection = out
        assert selection.shape==(feats.shape[0],)
        selection[:] = 1
    
    for l,h in s_regions:
        selection[l:h+1] = 0
    
    return selection

if __name__=='__main__':
    logging.basicConfig(level=logging.INFO)
    parser = get_parser()
    
    opts = parser.parse_args()
    
    feat_rdr = kaldi_io.SequentialBaseFloatMatrixReader(opts.feat_rx)
    feat_wrtr = kaldi_io.BaseFloatMatrixWriter(opts.feat_wx)
    if opts.selection_wx:
        sel_wrtr = kaldi_io.BaseFloatVectorWriter(opts.selection_wx)
    else:
        sel_wrtr = None
        
    for uttid, feats in feat_rdr:
        selection = select_feats(feats, opts)
        feats = feats[selection, :]
        feat_wrtr[uttid] = feats
        if sel_wrtr:
            sel_wrtr[uttid] = selection
