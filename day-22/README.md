# Noisevember 2019 -- day 22

## Goal

Add polyphony to the MIDI synth from day 21.

## Result

I reworked the synth to use a separate oscillator for each of the 128
MIDI notes, and gave each one a very basic envelope generator that is
turned on by MIDI note on messages and off by MIDI note off
messages. I also added handling for more types of MIDI messages.
