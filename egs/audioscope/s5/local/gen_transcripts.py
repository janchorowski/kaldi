#!/usr/bin/env python

import sys
import logging
import codecs

import kaldi_argparse
from IPython.utils.io import stdout

def get_parser():
    parser = kaldi_argparse.KaldiArgumentParser()
    parser.add_argument('rules_dir')
    parser.add_argument('text_file', default='-', nargs='?')
    parser.add_argument('phoneme_file', default='-', nargs='?')
    parser.add_standard_arguments()
    return parser


if __name__=='__main__':
    logging.basicConfig(level=logging.INFO)
    parser = get_parser()
    args = parser.parse_args()
    
    if args.text_file == '-':
        args.text_file = codecs.getreader('utf-8')(sys.stdin)
    else:
        args.text_file = codecs.open(args.text_file, 'r', 'utf-8')
        
    if args.phoneme_file == '-':
        args.phoneme_file = codecs.getwriter('utf-8')(sys.stdout)
    else:
        args.phoneme_file = codecs.open(args.phoneme_file, 'w', 'utf-8')
    
    logging.info("Appending %s to path", args.rules_dir)
    sys.path.append(args.rules_dir)
    from pronounce import PronRules, saySentence
    rules = PronRules(args.rules_dir)
    
    for line in args.text_file:
        line = line.strip()
        if line=="":
            continue
        phones = saySentence(line, rules)
        #logging.debug("phones: %s", phones)
        args.phoneme_file.write("%s\n" % (u" ".join(phones)),)
