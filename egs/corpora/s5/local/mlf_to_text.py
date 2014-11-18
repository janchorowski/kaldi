#!/usr/bin/env python
# -*- coding: utf-8 -*-
# 2014 Jan Chorowski
#
# script to transform .mlf files into .text files
'''
mlf_to_text.py
##################
.. argparse::
:module: __name__
:func: get_parser
:prog: TEMPLATE.py
'''

import logging
logger = logging.getLogger(__file__)

import kaldi_argparse

import re,sys

def get_parser():
    parser = kaldi_argparse.KaldiArgumentParser(description="Extract ",
                                                #epilog="""
                                                #Exemplary usage:
                                                
                                                #"""
                                            )
    #parser.add_argument('--foo', type=bool, default=False, help='do bar')
    parser.add_argument('mlf_file', default=None, nargs='?')
    parser.add_argument('text_file', default=None, nargs='?')
    parser.add_standard_arguments()
    return parser

phone_subst = {
    'a_' : '_a',
    'e_' : '_e',
    'l_' : '_l',
}

def read_mlf(mlf_in_file, text_out_file):
    #with open(mlf_file, 'rt') as mf:
    assert mlf_in_file.readline() == '#!MLF!#\n'

    utt_info_ended = True
    for line in mlf_in_file:
        line=line.strip()
        if utt_info_ended:
            utt_info_ended = False
            utt_id, = re.match('"\*/(.*)\.lab"', line).groups()
            utt_phones = []
        elif line == '.':
            utt_info_ended = True
            #utterances.append((utt_id, utt_phones))
            text_out_file.write("%s\t%s\n" %(utt_id, 
                                             ' '.join(utt_phones)
                                         ))
        else:
            unused_beg, unused_end, phone = line.split()
            phone  = phone_subst.get(phone, phone)
            utt_phones.append(phone)
    assert utt_info_ended

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    parser = get_parser()
    args = parser.parse_args()

    if args.mlf_file is None:
        args.mlf_file = sys.stdin
    else:
        args.mlf_file = open(args.mlf_file, 'r')
        
        
    if args.text_file is None:
        args.text_file = sys.stdout
    else:
        args.text_file = open(args.text_file, 'w')

    read_mlf(args.mlf_file, args.text_file)

    
