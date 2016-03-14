import sys
import os

"""
  This script is balancing set of waves according to their durations,
  using output of wav-to-duration. It assumes that uttid has form of:
  <some_speaker_id>__<wave_name> for example:

  someDirectory/Speaker_1__Wave_1

  It iterates over every speaker, choosing it's waves one by one
  until it reaches time limit in minutes, given as float. If there's
  no enough waves for some speakers, then it starts again from first
  wave on the list and so on. For each wave we print output in form:

  someDirectory/Speaker_1/Wave_1__<loop_number>

  where <loop_number> is to distinguish files, which were taken
  multiple times.
"""

if len(sys.argv) != 4:
  print "Usage: python balance_train_data.py <durs> <mins_limit> <loop_limit>"
  exit(1)

durs_file = open(sys.argv[1])
min_limit = float(sys.argv[2])
loop_limit = int(sys.argv[3])

durs = {}

for line in durs_file.readlines():
  if line == '\n':
    break
  splitted = line.split()
  dur = float(splitted[1])
  speaker, wav_name = splitted[0].split('__')

  if speaker not in durs:
    durs[speaker] = []

  durs[speaker].append((wav_name, dur))

for speaker in durs:
  all_dur = 0.0
  balance_done = False
  counter = 0
  while not balance_done:
    for wave_name, dur in durs[speaker]:
      all_dur += dur
      print speaker + '/' + wave_name + '__' + str(counter)
      if all_dur / 60.0 >= min_limit or counter == loop_limit - 1: # < loop_limit - 1 because indexing from 0
        balance_done = True
        break

    counter += 1
