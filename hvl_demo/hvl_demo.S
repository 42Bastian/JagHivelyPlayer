	.68000

	.include "68k_inc/jaguar.inc"
	.include "68k_inc/blit_eq.inc"
	.include "68k_mac/help.mac"
	.include "gpu.equ"
	.include "../player/hively_player.inc"
	.include "../player/u234se_pad.inc"

****************
vars		= $0001000

max_x_txt	= 320
max_y_txt	= 12*8

max_x		= rez_x
max_y_gr	= 100

txt_screen	= $000c0000
logo_screen	= txt_screen+(max_x_txt/8)*max_y_txt

ScreenMode	EQU CRY16|VIDEN|PWIDTH4|BGEN|CSYNC
******************
* variables

	RSRESET
	RSB obl,256
	RSL obls,2

	RSW a_vde
	RSW a_vdb
	RSW dummy
	.include "68k_var/text_scr.var"
	RSL oldPad
	RSL currentSong
	RSL volume
	RSL StackBottom,200
	RSL stack,1

vars_len	= RSCOUNT
	IF vars_len > (100*1024)
	FAIL
	ENDIF
******************

	;;----  SBL header ----
start:
	bra.w	start2
	dc.l	start
	dc.l	jag_end-start
	dc.l	0
start2:

init_68k:
	INCLUDE "68k_inc/startup.inc"
******************
* Main
	lea	vars,a6
	lea	stack(a6),sp
	lea	$f00000,a5

	move.l	a6,a0
	move.l	#vars_len,d0
	bsr	memzero

	lea	$f03000+$8000,a0
	move.l	#4096,d0
	bsr	memzero		; zero complete GPU ram

	lea	screen0,a0
	move.l	#$20000,d0
	bsr	memzero

	lea	screen1,a0
	move.l	#$20000,d0
	bsr	memzero

	lea	logo,a0
	lea	logo_screen,a1
	moveq	#8*9,d0
	bsr	memcpy

	;; Setup Text screen
	move.w	#254,d0
	move.l	#$1000F7F0,d1
	lea	txt_screen,a0
	move.l	a0,TextScreen(a6)
	bsr	InitTxtScreen

	;; Video setup
	bsr	VideoInit
	bsr	InitOP
	move.w #ScreenMode,$28(a5)

	move.l	#$100,volume(a6)

	bsr	InitGPU
	bsr	InitDSP

	;; Initial text out
	clr.l	Cursor(a6)
	lea	Hallo(pc),a0
	bsr	PrintA0

	moveq	#0,d7
	.globl again
again:
	stop	#$2000		; wait for GPU interrupt

//->	clr.l	Cursor(a6)
//->	move.l	DSP_sample_ptr,d0
//->	bsr	PrintHEXl

	move.l	#14<<16|3,d0
	move.l	d0,Cursor(a6)

	move.l	DSP_stream_pos,d0

	bsr	PrintHEXl

	move.l	DSP_song,a0
	move.l	song_length(a0),d0
	bsr	PrintHEXl
no_pos_change:
	move.l	DSP_pad1,d1
	move.l	oldPad(a6),d0
	move.l	d1,oldPad(a6)
	eor.l	d1,d0
	and.l	d1,d0

	moveq	#3,d2
	and.w	d1,d2
	beq.s	no_volume

	moveq	#4,d1
	btst	#U235SE_BBUT_UP,d2
	bne.s	up
	neg.l	d1
up:
	move.l	volume(a6),d0
	move.l	d0,d2
	add.l	d1,d2
	bmi.s	no_change
	cmp.l	#$200,d2
	bhi.s	no_change
	move.l	d2,d0
no_change:
	move.l	d0,volume(a6)
	move.l	d0,DSP_master_volume
	move.l	#8<<16|5,Cursor(a6)
	bsr	PrintDEZ
	bra	again

no_volume:
	btst.l	#U235SE_BBUT_0,d0
	beq.s	no_pause

	lea	DSP_flag_replay_ON_OFF,a0
	moveq	#5,d0
	move.l	(a0),d1
	beq.s	ok_pause
	cmp.l	d0,d1
	bne	again
ok_pause:
	eor.l	d0,d1
	move.l	d1,(a0)
	bra	again

no_pause:
	btst.l	#U235SE_BBUT_A,d0
	beq.s	no_restart
	lea	DSP_flag_replay_ON_OFF,a0
	moveq	#6,d0
	move.l	d0,(a0)
	subq	#1,d0
wait_restart:
	cmp.l	(a0),d0
	bne.s	wait_restart
	moveq	#0,d0
	move.l	d0,(a0)
	bra	again

no_restart:
	cmp.l	#5,DSP_flag_replay_ON_OFF ; paused/stopped
	bne.s	playing

	moveq	#0,d1
	btst	#U235SE_BBUT_1,d0
	bne.s	selected
	addq.l	#4,d1
	btst	#U235SE_BBUT_2,d0
	bne.s	selected
	addq.l	#4,d1
	btst	#U235SE_BBUT_3,d0
	bne.s	selected
	addq.l	#4,d1
	btst	#U235SE_BBUT_4,d0
	bne.s	selected
	addq.l	#4,d1
	btst	#U235SE_BBUT_5,d0
	bne.s	selected
	bra	playing
selected:
	move.l	d1,currentSong(a6)

	lea	songs(pc),a0
	move.l	0(a0,d1.w),DSP_song

	lsr.w	#2,d1
	move.w	d1,d0
	addq.w	#1,d0
	move.l	#33<<16|1,Cursor(a6)
	bsr	PrintDigit

	move.l	#6,DSP_flag_replay_ON_OFF
	bra	again

playing:
	btst	#U235SE_BBUT_C,d0
	beq	again
	lea	bell,a0
	add.l	a0,a0
	move.l	#(bell_e-bell)*2,DSP_sample_size
	move.l	a0,DSP_sample_ptr
	bra	again
******************
	.include "68k_inc/text_scr.inc"
******************
* InitDSP
InitDSP:
	lea	DSP_flag_replay_ON_OFF,a0
	moveq	#5,d0
	move.l	d0,(a0)+	; no song playing
	move.l	#panning_table,(a0)+
	move.l	#binPrecalcTable,(a0)+
	move.l	volume(a6),(a0)+	; master volume
	move.l	songs(pc),(a0)+

	lea	$f1a114,a0
	moveq	#0,d0
	move.l	d0,-(a0)
	lea	$f1b000,a1
	move.l	a1,(a0)+
	lea	DSPcode(pc),a2
	move.l	#(DSPcode_end-DSPcode)/4,d0
cpdsp:
	move.l	(a2)+,(a1)+
	dbra	d0,cpdsp
	moveq	#1,d0
	move.l	d0,(a0)
	rts
DSPcode:
	incbin "../player/hively_player.bin"
DSPcode_end:
panning_table:
	incbin "../player/AHX_panning.bin"
binPrecalcTable:
	incbin "../player/AHX_FilterPrecalc.bin"
******************
* InitGPU
InitGPU:
	lea	$00F02110,a4
	lea	GPUcode+4(pc),a0
	moveq	#0,d0
	move.l	d0,4(a4)	; GPU halt
	movea.l (a0)+,a1	; destination
	lea	$10(a1),a3	; skip 68k irq vector
	move.l	a3,(a4)		; set GPU PC
	move.l	(a0)+,d0	; Length in Bytes
	adda.l	#$8000,a1	; 32bit writes
	bsr	memcpy

	lea	parameter,a0
	movem.l	obls(a6),d0-d1
	moveq	#opl_size/8,d2
	movem.l	d0-d2,(a0)

	moveq.l	#1,d0
	move.l	d0,4(a4)	; start GPU
	rts

	.phrase
	dc.l	0		; dummy to align code after BJL header
GPUcode:
	incbin "gpu.o"
*****************
*    CopyOBL	*
CopyOBL:
	move.l	obls(a6),a1
	lea	obl(a6),a0
	moveq	#(obl1-obl0)/4-1,d0
co:
	move.l	(a1)+,(a0)+
	dbra	d0,co
	rts
*****************
*   videoinit	*
	.include "68k_inc/videoinit.inc"
*****************
*    InitOP	*
InitOP:
	lea	obls_50hz(pc),a0
	btst	#4,$00F14003
	beq.s	io_pal
	lea	obls_60hz(pc),a0
io_pal:
	movem.l	(a0),d0-d1
	movem.l	d0-d1,obls(a6)

	bsr	CopyOBL		; initial copy

	moveq	#0,d0
	move.w	a_vde(a6),d0
	move.w	d0,d1
	bclr	#0,d1
	move.w  d0,$48(a5)            ;; vde
	addq	#4,d0
	move.w d0,$4e(a5)

	lea	obl(a6),a0
	move.l	a0,d0
	swap	d0
	move.l	d0,OLP-_BASE(a5)
	move.l	#$1F02<<16,INT1-_BASE(a5)
	lea	my_irq(pc),a0
	move.l	a0,$00000100.w
	rts
******************
* IRQ
my_irq:
	move.l	#$202<<16,INT1
	rte

obls_50hz:	dc.l	obl0, obl1
obls_60hz:	dc.l	obl0_60hz, obl1_60hz

;;; memzero
;;; a0 - destination
;;; d0 - size
memzero:
	move.l	(sp)+,a2	; get return address (zeroing stack!)
mz0:
	move.l	d0,d1
	cmp.l	#$20000,d0
	blo.s	mz1
	move.l	#$20000,d1
mz1:
	sub.l	d1,d0
	lea	A1_BASE,a1
	move.l	a0,(a1)
	adda.l	d1,a0
	move.l	#BLIT_PITCH1|BLIT_PIXEL32|BLIT_WID3584|BLIT_XADDPHR,_BLIT_A1_FLAGS(a1)
	lsr.l	#2,d1
	bset	#16,d1
	move.l	d1,_BLIT_COUNT(a1)
	moveq	#0,d1
	move.l	d1,_BLIT_A1_PIXEL(a1)
	move.l	d1,_BLIT_CMD(a1)
wbl1:
	move.l	_BLIT_CMD(a1),d1
	btst	#0,d1
	beq.s	wbl1
	tst.l	d0
	bne.s	mz0
	jmp	(a2)

;;; memcpy with blitter
;;; A0 -> A1, size D0
memcpy:
	lea	A1_BASE,a2
	move.l	a1,(a2)
	move.l	a0,_BLIT_A2_BASE(a2)
	move.l	#BLIT_PITCH1|BLIT_PIXEL32|BLIT_WID3584|BLIT_XADDPHR,d1
	move.l	d1,_BLIT_A1_FLAGS(a2)
	move.l	d1,_BLIT_A2_FLAGS(a2)
	moveq	#0,d1
	move.l	d1,_BLIT_A1_PIXEL(a2)
	move.l	d1,_BLIT_A2_PIXEL(a2)

	lsr.w	#2,d0
	bset	#16,d0
	move.l	d0,_BLIT_COUNT(a2)
	move.l	#BLIT_SRCEN|BLIT_LFU_REPLACE,d0
	move.l	d0,_BLIT_CMD(a2)
mc_wbl1:
	move.l	_BLIT_CMD(a2),d0
	btst	#0,d0
	beq.s	mc_wbl1
	rts
******************
* text-data
	;;    0123456789012345678901234567890123456789
Hallo:	dc.b "JagHively Demo - Player by Ericde45     "
	dc.b "Press A to restart song          1      "
	dc.b "Press 0 to play/pause song              "
	dc.b "Song position:                          "
	dc.b "Press C to play sample                  "
	dc.b "Volume: 00255  (up/down)                "
	dc.b "----------------------------------------"
	dc.b "-1- Gone PiNk/abYSs                     "
	dc.b "-2- Headcrash (Hively Remix, Virgill)   "
	dc.b "-3- Echos in the Mist by Samurai_Crow   "
	dc.b "-4- Never gonna ... (Xeron)             "
	dc.b "-5- joey&splif-pantsomime               "

	dc.b 0

	.phrase
logo:
	;;    0123456789ABCDEF0123456789ABCDEF
	dc.l %11111111111111111111111111111110,0
	dc.l %10000000000000000000000000000010,0
	dc.l %10110001101000010010001001000010,0
	dc.l %10101010001010101001010101010010,0
	dc.l %10110001001110001000000101110010,0
	dc.l %10101000100010010000001000010010,0
	dc.l %10110011000010111000011100010010,0
	dc.l %10000000000000000000000000000010,0
	dc.l %11111111111111111111111111111110,0

*****************
* Objekte

vde_pal		equ (PAL_VMID+PAL_HEIGHT)/2+1
vde_ntsc	equ (NTSC_VMID+NTSC_HEIGHT)/2+1

bpp		= 4
gr_phrase	= max_x/4
y_start_pal	= 29
y_start_ntsc	= 24

	.phrase
obl0:

	.objproc
	.org	vars
 branch VC < 25,_stop0
 branch VC > vde_pal,_stop0
 branch	VC = vde_pal-1, _gpu01
 nop
 IF max_x < 320
 scbitmap screen0,9,y_start_pal+max_y_txt,gr_phrase,gr_phrase,max_y_gr,320.0/max_x,1.0,0.5,bpp,0,NOTRANS RELEASE,0,1
 ELSE
 bitmap screen0,10,y_start_pal+max_y_txt,gr_phrase,gr_phrase,max_y_gr+1,bpp,0,NOTRANS RELEASE,0,1
 ENDIF
 bitmap	txt_screen, 9,y_start_pal,(max_x_txt/64),(max_x_txt/64),max_y_txt, 0,127, TRANS RELEASE,0,1
 bitmap	logo_screen, 10,y_start_pal+max_y_txt+max_y_gr-9,1,1,9, 0,127,TRANS  RELEASE,0,1
 jump	_stop0
_gpu01:
 gpuobj 1
_stop0:
 stop

	.68000
obl1:
	.objproc
	.org	vars
 branch VC < 25,_stop1
 branch VC > vde_pal,_stop1
 branch	VC = vde_pal-1, _gpu11
 nop
 IF max_x < 320
 scbitmap screen1,9,y_start_pal+max_y_txt,gr_phrase,gr_phrase,max_y_gr,320.0/max_x,1.0,0.5,bpp,0,NOTRANS RELEASE,0,1
 ELSE
 bitmap screen1,10,y_start_pal+max_y_txt,gr_phrase,gr_phrase,max_y_gr+1,bpp,0,NOTRANSS RELEASE,0,1
 ENDIF
 bitmap	txt_screen, 9,y_start_pal,(max_x_txt/64),(max_x_txt/64),max_y_txt, 0,127, TRANS RELEASE,0,1
 bitmap	logo_screen, 10,y_start_pal+max_y_txt+max_y_gr-9,1,1,9, 0,127, TRANS RELEASE,0,1
 jump	_stop0
_gpu11:
 gpuobj 0
_stop1:
 stop
;; ======================================== 60Hz
	.68000
	.dphrase
obl0_60hz:
	.objproc
	.org	vars
 branch VC < 25,_stop0_60hz
 branch VC > vde_ntsc,_stop0_60hz
 branch	VC = vde_ntsc-1, _gpu01_60hz
 nop
 IF max_x < 320
 scbitmap screen0,11,y_start_ntsc+max_y_txt,gr_phrase,gr_phrase,max_y_gr,320.0/max_x,1.0,0.5,bpp,0,NOTRANS RELEASE,0,1
 ELSE
 bitmap screen0,11,y_start_ntsc+max_y_txt,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
 ENDIF
 bitmap	txt_screen, 11,y_start_ntsc,(max_x_txt/64),(max_x_txt/64),max_y_txt, 0,127, TRANS RELEASE,0,1
 bitmap	logo_screen, 12,y_start_ntsc+max_y_txt+max_y_gr-9,1,1,9, 0,127, TRANS RELEASE,0,1
 jump	_stop0_60hz
_gpu01_60hz:
 gpuobj 0
_stop0_60hz:
 stop

	.68000
obl1_60hz:
	.objproc
	.org	vars
 branch VC < 25,_stop1_60hz
 branch VC > vde_ntsc,_stop1_60hz
 branch	VC = vde_ntsc-1, _gpu11_60hz
 nop
 IF max_x < 320
 scbitmap screen1,11,y_start_ntsc+max_y_txt,gr_phrase,gr_phrase,max_y_gr,320.0/max_x,1.0,0.5,bpp,0,NOTRANS RELEASE,0,1
 ELSE
 bitmap screen1,11,y_start_ntsc+max_y_txt,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
 ENDIF
 bitmap	txt_screen, 11,y_start_ntsc,(max_x_txt/64),(max_x_txt/64),max_y_txt, 0,127, TRANS RELEASE,0,1
 bitmap	logo_screen, 12,y_start_ntsc+max_y_txt+max_y_gr-9,1,1,9, 0,127,TRANS  RELEASE,0,1
 jump	_stop1_60hz
_gpu11_60hz:
 gpuobj 1
_stop1_60hz:
 stop
	.68000
	.phrase
_end_60hz:

opl_size	= _end_60hz-obl1_60hz

	print "OPL (phrases) ",/u opl_size/8

songs:
	dc.l	gone
	dc.l	headcrash
	dc.l	echo6
	dc.l	chip
	dc.l	joey
song:
gone:
	incbin "hvl/gone.ahx.streambits"
headcrash:
	incbin "hvl/Virgill-Headcrash_Hively_Rmx.hvl.streambits"
echo6:
	incbin "hvl/echo6.hvl.streambits"
chip:
	incbin "hvl/chiprolled.hvl.streambits"
joey:
	incbin "hvl/joey_splif-pantsomime.hvl.streambits"
bell:
	.incbin "bell.raw"
bell_e:
	print "bell: ",/x/l bell*2
;;; ----------------------------------------
jag_end:
	BSS

	END
