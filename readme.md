# Hively MOD Player

This a reworked version of the orginal player by Ericde45.

The player is standalone and uses nearly all of the DSP RAM.

Default setup uses 10 channels and 4 ring modulation channels. If a song needs more RM channels, then they will be allocated in main RAM.

The player needs to be loaded into DSP RAM. At the top of the RAM is a parameter field (see player source) to be setup before start.

The HVL/AHX file needs to be converted with the `hvl2stream` for the Jaguar.

The player can also optionally scan the pads every HVL frame which is with 50,100,150 or 200Hz.

# The original tracker

https://github.com/pete-gordon/hivelytracker/tree/master
