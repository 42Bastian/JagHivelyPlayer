# hvl_demo

A small demo showing use of the Hively player.

`0` pauses the current song.
`A` starts the song from the beginning
`B` stops the song (and currently also the DSP!)
`1`..`5` select a song (when stopped)

Since `B` stops the DSP, there is also pad reading in the 68k code.

BJL uses original bit positions, therefore two differnet checks in the code.

## Starting ROM

The ROM can be used with BPE (enable BootROM!) or GD. Does not work on SKUNK!

## GD

   `jaggd -rd -uxr hvl_demo.j64,a:0x800000`
