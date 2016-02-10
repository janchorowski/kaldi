#!/usr/bin/env python

import sys
import os

if len(sys.argv) != 3:
  print "Usage: python arpa2lex.py <arpa_file> <rules_dir>"
  exit(1)

try:
  arpa_file = open(sys.argv[1])
except:
  print "Couldn't open arpa file ", sys.argv[1]
  exit(2)

for line in arpa_file:
  if line == "\\1-grams:\n":
    break

for line in arpa_file:
  if line == '\n' or line == "\\end":
    break

  word = line.split()[1]

  if word != "<s>" and word != "</s>" and word != "sil":
    sys.stdout.write(word + " ")
    sys.stdout.flush()
    os.system("echo " + word + "| local/gen_transcripts.py " + sys.argv[2])
  elif word == "sil":
    sys.stdout.write("sil sil\n")
    sys.stdout.flush()

arpa_file.close()
