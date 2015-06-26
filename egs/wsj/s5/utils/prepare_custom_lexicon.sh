#!/bin/bash
sil_prob=0.5

. utils/parse_options.sh 

if [ $# -ne 4 ]; then 
  echo "usage: utils/prepare_custom_lexicon.sh <lang> <dict-src-dir> <tmp-dir> <graph-dir>"
  echo "e.g.: utils/prepare_custom_lexicon.sh data/lang custom/dict custom/lang/tmp custom/lang"
  echo "<dict-src-dir> should contain the following files:"
  echo "lexicon.txt "
  echo "<dict-src-dir> can also contain the following files:"
  echo "lexiconp_silprob.txt "
  echo "See http://kaldi.sourceforge.net/data_prep.html#data_prep_lang_creating for more info."
  echo "options: "
  echo "     --sil-prob <probability of silence>             # default: 0.5 [must have 0 <= silprob < 1]"
  exit 1;
fi

langdir=$1
srcdir=$2
tmpdir=$3
dir=$4

mkdir -p $dir $tmpdir $dir/phones

silprob=false
[ -f $srcdir/lexiconp_silprob.txt ] && silprob=true

[ -f path.sh ] && . ./path.sh

if [[ ! -f $srcdir/lexicon.txt ]]; then
  echo "**Creating $dir/lexicon.txt from $dir/lexiconp.txt"
  perl -ape 's/(\S+\s+)\S+\s+(.+)/$1$2/;' < $srcdir/lexiconp.txt > $srcdir/lexicon.txt || exit 1;
fi
if [[ ! -f $srcdir/lexiconp.txt ]]; then
  echo "**Creating $srcdir/lexiconp.txt from $srcdir/lexicon.txt"
  perl -ape 's/(\S+\s+)(.+)/${1}1.0\t$2/;' < $srcdir/lexicon.txt > $srcdir/lexiconp.txt || exit 1;
fi

if "$silprob"; then 
  cp $srcdir/lexiconp_silprob.txt $tmpdir/lexiconp_silprob.txt
fi

cp $srcdir/lexiconp.txt $tmpdir/lexiconp.txt

# add disambig symbols to the lexicon in $tmpdir/lexiconp.txt
# and produce $tmpdir/lexicon_*disambig.txt

if "$silprob"; then
  ndisambig=`utils/add_lex_disambig.pl --pron-probs --sil-probs $tmpdir/lexiconp_silprob.txt $tmpdir/lexiconp_silprob_disambig.txt`
else
  ndisambig=`utils/add_lex_disambig.pl --pron-probs $tmpdir/lexiconp.txt $tmpdir/lexiconp_disambig.txt`
fi
ndisambig=$[$ndisambig+1]; # add one disambig symbol for silence in lexicon FST.
echo $ndisambig > $tmpdir/lex_ndisambig

mkdir -p $dir/phones

# Format of lexiconp_disambig.txt:
# !SIL	1.0   SIL_S
# <SPOKEN_NOISE>	1.0   SPN_S #1
# <UNK>	1.0  SPN_S #2
# <NOISE>	1.0  NSN_S
# !EXCLAMATION-POINT	1.0  EH2_B K_I S_I K_I L_I AH0_I M_I EY1_I SH_I AH0_I N_I P_I OY2_I N_I T_E

cp $langdir/phones/{silence,nonsilence}.txt $dir/phones
( for n in `seq 0 $ndisambig`; do echo '#'$n; done ) >$dir/phones/disambig.txt

# Create phone symbol table.
echo "<eps>" | cat - $dir/phones/{silence,nonsilence,disambig}.txt | \
  awk '{n=NR-1; print $1, n;}' > $dir/phones.txt 

cp $langdir/phones/optional_silence.txt $srcdir

# Create these lists of phones in colon-separated integer list form too, 
# for purposes of being given to programs as command-line options.
for f in silence nonsilence disambig; do
  utils/sym2int.pl $dir/phones.txt <$dir/phones/$f.txt >$dir/phones/$f.int
  utils/sym2int.pl $dir/phones.txt <$dir/phones/$f.txt | \
   awk '{printf(":%d", $1);} END{printf "\n"}' | sed s/:// > $dir/phones/$f.csl || exit 1;
done


# Create word symbol table.
# <s> and </s> are only needed due to the need to rescore lattices with
# ConstArpaLm format language model. They do not normally appear in G.fst or
# L.fst.

if "$silprob"; then
  # remove the silprob
  cat $tmpdir/lexiconp_silprob.txt |\
    awk '{
      for(i=1; i<=NF; i++) {
        if(i!=3 && i!=4 && i!=5) printf("%s\t", $i); if(i==NF) print "";
      }
    }' > $tmpdir/lexiconp.txt
fi

cat $tmpdir/lexiconp.txt | awk '{print $1}' | sort | uniq  | awk '
  BEGIN {
    print "<eps> 0";
  } 
  {
    if ($1 == "<s>") {
      print "<s> is in the vocabulary!" | "cat 1>&2"
      exit 1;
    }
    if ($1 == "</s>") {
      print "</s> is in the vocabulary!" | "cat 1>&2"
      exit 1;
    }
    printf("%s %d\n", $1, NR);
  }
  END {
    printf("#0 %d\n", NR+1);
    printf("<s> %d\n", NR+2);
    printf("</s> %d\n", NR+3);
  }' > $dir/words.txt || exit 1;

# format of $dir/words.txt:
#<eps> 0
#!EXCLAMATION-POINT 1
#!SIL 2
#"CLOSE-QUOTE 3
#...

silphone=`cat $srcdir/optional_silence.txt` || exit 1;
[ -z "$silphone" ] && \
  ( echo "You have no optional-silence phone; it is required in the current scripts"
    echo "but you may use the option --sil-prob 0.0 to stop it being used." ) && \
   exit 1;

# create $dir/phones/align_lexicon.{txt,int}.
# This is the new-new style of lexicon aligning.

# Create the basic L.fst without disambiguation symbols, for use
# in training. 

if $silprob; then
  # Usually it's the same as having a fixed-prob L.fst
  # it matters a little bit in discriminative trainings
  utils/make_lexicon_fst_silprob.pl $tmpdir/lexiconp_silprob_disambig.txt $srcdir/silprob.txt $silphone '#'$ndisambig | \
     sed 's=\#[0-9][0-9]*=<eps>=g' | \
     fstcompile --isymbols=$dir/phones.txt --osymbols=$dir/words.txt \
     --keep_isymbols=false --keep_osymbols=false |   \
     fstarcsort --sort_type=olabel > $dir/L.fst || exit 1;
else
  utils/make_lexicon_fst.pl --pron-probs $tmpdir/lexiconp.txt $sil_prob $silphone | \
    fstcompile --isymbols=$dir/phones.txt --osymbols=$dir/words.txt \
    --keep_isymbols=false --keep_osymbols=false | \
     fstarcsort --sort_type=olabel > $dir/L.fst || exit 1;
fi

# Create the lexicon FST with disambiguation symbols, and put it in lang_test.
# There is an extra step where we create a loop to "pass through" the
# disambiguation symbols from G.fst.
phone_disambig_symbol=`grep \#0 $dir/phones.txt | awk '{print $2}'`
word_disambig_symbol=`grep \#0 $dir/words.txt | awk '{print $2}'`

if $silprob; then
  utils/make_lexicon_fst_silprob.pl $tmpdir/lexiconp_silprob_disambig.txt $srcdir/silprob.txt $silphone '#'$ndisambig | \
     fstcompile --isymbols=$dir/phones.txt --osymbols=$dir/words.txt \
     --keep_isymbols=false --keep_osymbols=false |   \
     fstaddselfloops  "echo $phone_disambig_symbol |" "echo $word_disambig_symbol |" | \
     fstarcsort --sort_type=olabel > $dir/L_disambig.fst || exit 1;
else
  utils/make_lexicon_fst.pl --pron-probs $tmpdir/lexiconp_disambig.txt $sil_prob $silphone '#'$ndisambig | \
     fstcompile --isymbols=$dir/phones.txt --osymbols=$dir/words.txt \
     --keep_isymbols=false --keep_osymbols=false |   \
     fstaddselfloops  "echo $phone_disambig_symbol |" "echo $word_disambig_symbol |" | \
     fstarcsort --sort_type=olabel > $dir/L_disambig.fst || exit 1;
fi


cat $srcdir/lm.arpa | \
  grep -v '<s> <s>' | \
  grep -v '</s> <s>' | \
  grep -v '</s> </s>' | \
  arpa2fst - | \
  fstprint | \
  eps2disambig.pl |\
  s2eps.pl | \
  fstcompile --isymbols=$dir/words.txt \
    --osymbols=$dir/words.txt  \
    --keep_isymbols=false --keep_osymbols=false | \
  fstrmepsilon > $dir/G.fst 

exit 0;

