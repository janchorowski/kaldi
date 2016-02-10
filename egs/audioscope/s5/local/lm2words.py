#!/usr/bin/env python

import sys
import os

if len(sys.argv) != 2:
  print "Usage: python arpa2lex.py <arpa_file>"
  exit(1)

try:
  arpa_file = open(sys.argv[1])
except:
  print "Couldn't open arpa file ", sys.argv[1]
  exit(2)

for line in arpa_file:
  if line == "\\1-grams:\n":
    break

print "sil"

for line in arpa_file:
  if line == '\n' or line.startswith("\\end"):
    break

  word = line.split()[1]

  if word != "<s>" and word != "</s>" and word != "sil":
    print word

arpa_file.close()
