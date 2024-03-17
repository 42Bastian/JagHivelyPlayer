# hvl_demo

A small demo showing use of the Hively player.

`0` pauses the current song.
`A` starts the song from the beginning
`B` stops the song (and currently also the DSP!)

Since `B` stops the DSP, there is also pad reading in the 68k code.

BJL uses original bit positions, therefore two differnet checks in the code.
