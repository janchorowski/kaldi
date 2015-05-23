#!/bin/bash

stage=0

. utils/parse_options.sh 

if [ $# -ne 1 ]; then 
  echo "usage: utils/prepare_assimilation_voiced_lexicon.sh <lang-dir>"
  exit 1;
fi

dir=$1

[ -f lang/words-assimilation.txt ] || cp $dir/words.txt $dir/words-assimilation.txt

if [ $stage -le 0 ]; then
	cat $dir/words-assimilation.txt | python -c "if True:
	import re
	import sys
	
	word_id=0
	
	line = sys.stdin.readline().strip().split()
	while line:
		if not re.match('[BD?]_.*_[BD?]+', line[0]):
			print '%s %d' % (line[0], word_id)
			word_id += 1
			line = sys.stdin.readline().strip().split()
		else:
			break
	
	words = set()	
	while line:
		m = re.match('[BD?]_(.*)_[BD?]+', line[0])
		if m:
			words.add(m.group(1))
			line = sys.stdin.readline().strip().split()
		else:
			for w in sorted(words):
				print '%s %d' % (w, word_id)
				word_id += 1
			break
	
	while line:
		if not re.match('[BD?]_.*_[BD?]+', line[0]):
			print '%s %d' % (line[0], word_id)
			word_id += 1
			line = sys.stdin.readline().strip().split()
		else:
			break
	" > $dir/words.txt
fi

if [ $stage -le 1 ]; then
	cat $dir/words-assimilation.txt | python -c "if True:
	import re
	import sys
	
	states = {}
	
	#add epsilon transition to make sure that state 0 is the initial one and state 1 is BD?
	print '0 1 <eps> <eps>'
	#here BD? must be first
	for state in ['BD?', 'B', 'D', '?', 'B?', 'D?', 
				 ]:
		print '%d' % (len(states)+1, ) #mark terminal state
		states[state] = len(states)+1
	
	for line in sys.stdin:
		line = line.strip().split()
		w_in = line[0]
		m = re.match('([BD?])_(.*)_([BD?]+)', w_in)
		if m:
			prev_voiced = m.group(1)
			w_out = m.group(2)
			next_voiced = m.group(3)
			next_voiced_id = states[next_voiced]
			for state in states:
				if prev_voiced in state:
					print '%d %d %s %s' % (states[state], next_voiced_id, w_in, w_out)
		else:
			if w_in=='<eps>':
				continue
			for state in states.values():
				#add a self-loop
				print '%d %d %s %s' %(state, state, w_in, w_in)
	" | fstcompile --isymbols=lang/words-assimilation.txt --osymbols=lang/words.txt \
	  | fstrmepsilon > $dir/voicing.fst
fi

if [ $stage -le 2 ]; then
	[ -f $dir/L.orig.fst ] || mv $dir/L.fst $dir/L.orig.fst
	[ -f $dir/L_disambig.orig.fst ] || mv $dir/L_disambig.fst $dir/L_disambig.orig.fst  
	fstcompose $dir/L.orig.fst $dir/voicing.fst $dir/L.fst
	fstcompose $dir/L_disambig.orig.fst $dir/voicing.fst $dir/L_disambig.fst
fi

if [ $stage -le 3 ]; then
	#fix files whose content depend on words.txt
	
	# create phones/align_lexicon.int
	#cat $dir/phones/align_lexicon.txt | utils/sym2int.pl -f 3- $dir/phones.txt | \
	#	utils/sym2int.pl -f 1-2 $dir/words.txt > $dir/phones/align_lexicon.int
		
	cat $dir/oov.txt | utils/sym2int.pl $dir/words.txt >$dir/oov.int || exit 1;
fi
