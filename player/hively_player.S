        include "jaguar.inc"
  .dsp

;;; Compiletime configuration
READ_PAD        equ 1
UPDATE_SONG_POS equ 1
DISPLAY_TIME    equ 1

;;; ----------------------------------------
;;; parameters
DSP_song                        equ $f1d000-4
DSP_master_volume               equ $f1d000-8
DSP_filterPreCalcTable          equ $f1d000-12
DSP_panning_table               equ $f1d000-16
;;; 0 = running
;;; 1 = i2S stopping
;;; 2 = timer1 stopping / I2S stopped
;;; 3 = main stopping
;;; 4 = DSP stopped
;;; 5 = pause playing
;;; 6 = (re)start new song
DSP_flag_replay_ON_OFF          equ $f1d000-20
; xxxxxxCx xxBx2580 147*oxAP 369#RLDU
DSP_pad2                        equ $f1d000-24 ; read by 68k/GPU
DSP_pad1                        equ $f1d000-28 ; read by 68k/GPU
DSP_real_sample_rate            equ $f1d000-32 ; read by 68k/GPU
DSP_stream_pos                  equ $f1d000-36 ; read by 68k/GPU
DSP_sample_ptr                  equ $f1d000-40
DSP_sample_size                 equ $f1d000-44
DSP_sample_fade                 equ $f1d000-48 ; 0 => left, $100 => right (TBD)
DSP_sample_volume               equ $f1d000-52 ; 0 => silent, $100 full   (TBD)
;;; ----------------------------------------
;;; Configuration (constant)
max_NB_channels         equ 10
max_RM_channels         equ 4             ; max. RM buffers in DSP RAM
RM_buffers_main         equ $200        ; start of RM buffers in main
DSP_Audio_frequence     equ 32000

AHX_nb_bits_virgule_increment_period  .equ   16

SCLK_PAL        equ ((26593900*4/DSP_Audio_frequence+128)>>8)-1
DSP_frequence_de_replay_PAL equ 26593900/(SCLK_PAL+1)/64
A2J_RATIO_PAL   equ ((3546895<<9)/DSP_frequence_de_replay_PAL)<<(AHX_nb_bits_virgule_increment_period-9)

SCLK_NTSC       equ ((26590906*4/DSP_Audio_frequence+128)>>8)-1
DSP_frequence_de_replay_NTSC equ 26590906/(SCLK_NTSC+1)/64
A2J_RATIO_NTSC  equ ((3546895<<9)/DSP_frequence_de_replay_NTSC)<<(AHX_nb_bits_virgule_increment_period-9)

;;; ----------------------------------------
;;; Song header
song_NB_channel         equ 0
song_speed_multiplier   equ 1
song_panningLeft        equ 2
song_panningRight       equ 3
song_rm_channels        equ 4
song_restart_word       equ 8
song_restart_bit        equ 12
song_length             equ 16
song_header_size        equ 20
;;; ----------------------------------------

; HIVELY_datas_channels
DSP_index_vc_AudioVolume      equ  0
DSP_index_vc_Waveform         equ  1
DSP_index_vc_SquarePos        equ  2
DSP_index_vc_WaveLength       equ  3
DSP_index_vc_FilterPos        equ  4
DSP_index_vc_AudioPeriod      equ  5
DSP_index_vc_channel_on_off   equ  6
DSP_index_vc_RingWaveform     equ  7
DSP_index_vc_RingAudioPeriod  equ  8
DSP_index_vc_total            equ  9

; #I2S_sample_voices
I2S_index_sample_vc_offset        equ 0
I2S_index_sample_vc_increment     equ 1
I2S_index_sample_vc_loop_mask     equ 2
I2S_index_sample_vc_buffer        equ 3
I2S_index_sample_vc_panning_L     equ 4
I2S_index_sample_vc_panning_R     equ 5
I2S_index_sample_vc_offset_RM     equ 6
I2S_index_sample_vc_increment_RM  equ 7
I2S_index_sample_vc_buffer_RM     equ 8
I2S_index_sample_vc_total         equ 9

;------------------------------------------------------------
I2S_tmp_1                 equr  R0
I2S_tmp_2                 equr  R1
; left sample
I2S_offset_fixp_L         equr  R2
I2S_increment_fixp_L      equr  R3
I2S_loop_mask_L           equr  R4
I2S_sample_buffer_addr_L  equr  R5
; right sample
I2S_offset_fixp_R         equr  R6
I2S_increment_fixp_R      equr  R7
I2S_loop_mask_R           equr  R8
I2S_sample_buffer_addr_R  equr  R9

I2S_LOOP                  equr  R10
I2S_sample_L              equr  R11
I2S_sample_R              equr  R12
I2S_word_read_mask        equr  R13
I2S_sample_voice_ptr_L    equr  R14
I2S_sample_voice_ptr_R    equr  R15
I2S_voice_cnt             equr  R16
; R17
I2S_DAC_L                 equr  R18       ; init par moveta
I2S_DAC_R                 equr  R19       ; init par moveta
; R20
I2S_tmp_3                 equr  R21
I2S_tmp_4                 equr  R22
I2S_tmp_sample_L          equr  R23
I2S_tmp_sample_R          equr  R24
I2S_routine_actuelle      equr  R28
I2S_save_flags            equr  R29
;R30=used
;R31=stack

 .org D_RAM
 movei  #DSP_routine_init,r0
 jump   (r0)
 nop
        .align 16
DSP_ISP:
;--------------------------------------------
; I2S interrupt
 movei  #D_FLAGS,r30
 movei  #DSP_NB_channels,I2S_voice_cnt
 jump   (I2S_routine_actuelle)
 load   (r30),I2S_save_flags    ; read flags

;--------------------------------------------
; Timer 1 interrupt
 movei  #D_FLAGS,r30
 movei  #DSP_flag_replay_ON_OFF,I2S_tmp_1
 load   (r30),r29                 ; read flags
 load   (I2S_tmp_1),I2S_tmp_2
 moveq  #3,I2S_tmp_3
 cmpq   #2,I2S_tmp_2            ; stop timer 1?
 moveta I2S_tmp_3,r21           ; set flag for main loop
 jr     ne,DSP_timer1_exit
 bclr   #3,R29                  ; clear IMASK

 bclr   #6,R29                  ; clear Timer 1 Interrupt Enable Bit
 store  I2S_tmp_3,(I2S_tmp_1)

DSP_timer1_exit:
 load   (r31),I2S_tmp_3         ; return address
 bset   #11,R29                 ; clear latch 1 = timer 1
 addqt  #2,I2S_tmp_3            ; next instruction
 addq   #4,r31                  ; pop from stack
 jump   (I2S_tmp_3)             ; return
 store  R29,(R30)               ; restore flags

;;; --------------------------------------------------
; I2S:
; version sans adaptation du volume, avec SAT
I2S_main_interrupt:
 load   (I2S_voice_cnt),I2S_voice_cnt
 movei  #I2S_sample_voices,I2S_sample_voice_ptr_L
 moveq  #(I2S_index_sample_vc_total*4)-8,I2S_sample_voice_ptr_R
 moveq  #%00000010,I2S_word_read_mask
 add    I2S_sample_voice_ptr_L,I2S_sample_voice_ptr_R
 moveq  #0,I2S_sample_L
 addq   #8,I2S_sample_voice_ptr_R
 moveq  #0,I2S_sample_R

; offset 16.16
; increment 16.16
; mask bouclage
; adresse buffer sample

 move   pc,I2S_LOOP
 addq   #4,I2S_LOOP
I2S_voice_loop:
 load   (I2S_sample_voice_ptr_L), I2S_offset_fixp_L
 load   (I2S_sample_voice_ptr_R), I2S_offset_fixp_R
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_increment), I2S_increment_fixp_L
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_increment), I2S_increment_fixp_R

 add    I2S_increment_fixp_L,I2S_offset_fixp_L

 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_loop_mask), I2S_loop_mask_L
 add    I2S_increment_fixp_R,I2S_offset_fixp_R
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_loop_mask), I2S_loop_mask_R

 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_buffer), I2S_sample_buffer_addr_L
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_buffer), I2S_sample_buffer_addr_R

 store  I2S_offset_fixp_L,(I2S_sample_voice_ptr_L)
 store  I2S_offset_fixp_R,(I2S_sample_voice_ptr_R)

 and    I2S_loop_mask_L,I2S_offset_fixp_L      ; mask a virgule sur offset à virgule
 and    I2S_loop_mask_R,I2S_offset_fixp_R

 sharq  #AHX_nb_bits_virgule_increment_period-1,I2S_offset_fixp_L
 sharq  #AHX_nb_bits_virgule_increment_period-1,I2S_offset_fixp_R

 add    I2S_sample_buffer_addr_L,I2S_offset_fixp_L
 add    I2S_sample_buffer_addr_R,I2S_offset_fixp_R

 load   (I2S_offset_fixp_L),I2S_tmp_sample_L
 load   (I2S_offset_fixp_R),I2S_tmp_sample_R

 and    I2S_word_read_mask,I2S_offset_fixp_L
 and    I2S_word_read_mask,I2S_offset_fixp_R
 shlq   #3,I2S_offset_fixp_L
 shlq   #3,I2S_offset_fixp_R
 sha    I2S_offset_fixp_L,I2S_tmp_sample_L
 sha    I2S_offset_fixp_R,I2S_tmp_sample_R

 ; si on a 2 words sur 1 .L
 ; l'adresse doit etre multipliée par 2, plus par 4
 ; and avec %00010000 : on elimine le reste de virgule, et on ne garde que 0 ou 1 sur l'adresse *2
 ; sharq #4 : de 0 ou 16 => 0 ou 1
 ; il faut aboutir a un sharq 0 ou 16
 ; ====> pas de sharq
 ; juste sharq adresse sur sample


; RM à gérer ici
; voie G
; load l'increment et si =0 => pas de RM
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_increment_RM), I2S_increment_fixp_L
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_increment_RM), I2S_increment_fixp_R

 cmpq   #0,I2S_increment_fixp_L
 jr     eq,I2S_main_interrupt_no_RM_L
; RM left voice
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_offset_RM), I2S_offset_fixp_L
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_buffer_RM), I2S_sample_buffer_addr_L
 add    I2S_increment_fixp_L,I2S_offset_fixp_L
 store  I2S_offset_fixp_L,(I2S_sample_voice_ptr_L+I2S_index_sample_vc_offset_RM)
 and    I2S_loop_mask_L,I2S_offset_fixp_L
 sharq  #AHX_nb_bits_virgule_increment_period-2,I2S_offset_fixp_L
 add    I2S_sample_buffer_addr_L,I2S_offset_fixp_L
 load   (I2S_offset_fixp_L),I2S_increment_fixp_L
 imult  I2S_increment_fixp_L,I2S_tmp_sample_L
 sharq  #7,I2S_tmp_sample_L

I2S_main_interrupt_no_RM_L:
 cmpq   #0,I2S_increment_fixp_R
 jr     eq,I2S_main_interrupt_no_RM_R
; RM right voice
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_offset_RM), I2S_offset_fixp_R
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_buffer_RM), I2S_sample_buffer_addr_R
 add    I2S_increment_fixp_R,I2S_offset_fixp_R
 store  I2S_offset_fixp_R,(I2S_sample_voice_ptr_R+I2S_index_sample_vc_offset_RM)
 and    I2S_loop_mask_R,I2S_offset_fixp_R
 sharq  #AHX_nb_bits_virgule_increment_period-2,I2S_offset_fixp_R   ; -2 pour *4
 add    I2S_sample_buffer_addr_R,I2S_offset_fixp_R
 load   (I2S_offset_fixp_R),I2S_increment_fixp_R   ; lit le sample en .L, du RM
 imult  I2S_increment_fixp_R,I2S_tmp_sample_R
 sharq  #7,I2S_tmp_sample_R

I2S_main_interrupt_no_RM_R:
; stereo panning
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_panning_L),I2S_tmp_1    ; voie 1 / panning left
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_panning_L),I2S_tmp_3    ; voie 2 / panning left
 load   (I2S_sample_voice_ptr_L+I2S_index_sample_vc_panning_R),I2S_tmp_2    ; voie 1 / panning right
 load   (I2S_sample_voice_ptr_R+I2S_index_sample_vc_panning_R),I2S_tmp_4    ; voie 2 / panning right

; sample * panning
; sample = 14 bits : 8+6(volume)
; panning = 8 bits
; 14+8=22
; 22-7=15
; 15+15 => 16
 imultn I2S_tmp_sample_L,I2S_tmp_1
 imacn  I2S_tmp_sample_R,I2S_tmp_3
 resmac I2S_tmp_1

 imultn I2S_tmp_sample_L,I2S_tmp_2
 imacn  I2S_tmp_sample_R,I2S_tmp_4
 resmac I2S_tmp_2

 moveq  #I2S_index_sample_vc_total,I2S_tmp_3
 sharq  #7,I2S_tmp_1
 shlq   #2+1,I2S_tmp_3
 sharq  #7,I2S_tmp_2

 add    I2S_tmp_1,I2S_sample_L
 add    I2S_tmp_2,I2S_sample_R

 add    I2S_tmp_3,I2S_sample_voice_ptr_L

 subq   #2,I2S_voice_cnt
 jump   ne,(I2S_LOOP)
 add    I2S_tmp_3,I2S_sample_voice_ptr_R

continue_I2S:
 movei  #DSP_sample_ptr,I2S_tmp_1
 sat16s I2S_sample_L
 load   (I2S_tmp_1),I2S_tmp_2
 sat16s I2S_sample_R
 subqt  #4,I2S_tmp_1
 cmpq   #0,I2S_tmp_2
 move   I2S_tmp_2,I2S_tmp_3
 jr     eq,no_sample
 shrq   #1,I2S_tmp_3
 addqt  #1,I2S_tmp_2
 loadb  (I2S_tmp_3),I2S_tmp_3
 shlq   #24,I2S_tmp_3
 sharq  #16,I2S_tmp_3
 add    I2S_tmp_3,I2S_sample_L
 load   (I2S_tmp_1),I2S_tmp_4
 add    I2S_tmp_3,I2S_sample_R
 subq   #1,I2S_tmp_4
 store  I2S_tmp_4,(I2S_tmp_1)
 jr     ne,no_sample0
 addqt  #4,I2S_tmp_1

 moveq  #0,I2S_tmp_2
no_sample0:
 store  I2S_tmp_2,(I2S_tmp_1)

no_sample:
 movei  #DSP_master_volume,I2S_tmp_1
 sat16s  I2S_sample_L
 load   (I2S_tmp_1),I2S_tmp_1
 sat16s  I2S_sample_R

 imult  I2S_tmp_1,I2S_sample_L
 imult  I2S_tmp_1,I2S_sample_R

 sharq  #8,I2S_sample_L
 sharq  #8,I2S_sample_R

 sat16s  I2S_sample_L
 sat16s  I2S_sample_R

 store  I2S_sample_L,(I2S_DAC_L)
 store  I2S_sample_R,(I2S_DAC_R)

; return from interrupt I2S

 load   (r31),I2S_tmp_1         ; return address
 bclr   #3,I2S_save_flags       ; clear IMASK
 addqt  #2,I2S_tmp_1            ; next instruction
 bset   #10,I2S_save_flags      ; clear latch 1 = I2S
 addq   #4,r31                  ; pop from stack
 jump   (I2S_tmp_1)             ; return
 store  I2S_save_flags,(R30)    ; restore flags

;;; ----------------------------------------
;;; -- I2S only for SFX, no song
;;; ----------------------------------------
empty_i2s:
 movei  #continue_I2S,I2S_tmp_1
 moveq  #0,I2S_sample_L
 jump   (I2S_tmp_1)
 moveq  #0,I2S_sample_R

;------------------------------------------
;------------------------------------------
; ------------- main DSP ------------------
;------------------------------------------
;------------------------------------------

song_data_ptr   equr    r29
multiplier      equr    r28
panningDftLeft  equr    r27
panningDftRight equr    r26
panningTableL   equr    r25
panningTableR   equr    r24
nextVoice       equr    r23
rm_mask         equr    r22
local_data      equr    r15
voiceTable      equr    r14

;; local data indexes
streamingbits_index     equ 0
streamingbits_cur_index equ 1
streamingbits_end_index equ 2
NB_channel_index        equ 3

DSP_routine_init:
 movei  #D_FLAGS,r0
 moveq  #0,r1
 bset   #14,r1
 store  r1,(r0)                 ; switch to bank 1
 nop
 nop

;;; ----------------------------------------
;;; Setup timer1 and I2C
 movei  #A2J_RATIO_PAL,r12
 movei  #SCLK_PAL,r11
 movei  #DSP_frequence_de_replay_PAL,r10
 movei  #JOYBUTS,r0
 loadw  (r0),r3
 btst   #4,r3
 jr     eq,initPAL
 nop
 movei  #A2J_RATIO_NTSC,r12
 movei  #SCLK_NTSC,r11
 movei  #DSP_frequence_de_replay_NTSC,r10

initPAL:
 movei  #DSP_real_sample_rate,R2
 store  R10,(R2)
 movei  #DSP_ratio_Amiga_Jaguar__a_virgule_9_bits,R2
 store  R12,(R2)

        ; moveta, constantes I2S
 movei  #L_I2S,R0
 moveta R0,I2S_DAC_R
 addq   #4,r0
 moveta R0,I2S_DAC_L
//-> movei  #I2S_main_interrupt,R0
 movei  #empty_i2s,r0
 moveta R0,I2S_routine_actuelle

; init I2S
 movei  #SCLK,r0
 moveq  #%001101,r13     ; SMODE bascule sur RISING
 store  r11,(r0)         ; SCLK
 addq   #4,r0
 store  r13,(r0)         ; SMODE

; assume run from bank 1
 movei  #DSP_ISP,r31    ; init isp
 moveta r31,r31         ; ISP (bank 0)

restart_with_new_song:

 .if UPDATE_SONG_POS = 1
 moveq  #0,r0
 movei  #DSP_stream_pos,r1
 store  r0,(r1)
 .endif

 movei  #DSP_song,song_data_ptr
 movei  #DSP_localData,local_data
 load   (song_data_ptr),song_data_ptr

 loadb  (song_data_ptr),r0 ;
 store  r0,(local_data+NB_channel_index)
 addq   #1,song_data_ptr

 loadb  (song_data_ptr),multiplier
 addq   #1,song_data_ptr
 loadb  (song_data_ptr),panningDftLeft
 addq   #1,song_data_ptr
 loadb  (song_data_ptr),panningDftRight
 addq   #1,song_data_ptr

 load   (song_data_ptr),rm_mask
 addq   #4,song_data_ptr

 addq   #8,song_data_ptr        ; skip restart_word and bit

 load   (song_data_ptr),r0      ; length
 addq   #4,song_data_ptr

 store  song_data_ptr,(local_data)
 store  song_data_ptr,(local_data+streamingbits_cur_index)
 add    r0,song_data_ptr
 store  song_data_ptr,(local_data+streamingbits_end_index)

 ; left  : 1 4 5 8  9 12 13 16
 ; right : 2 3 6 7 10 11 14 15

initPanning:
 movei  #DSP_panning_table,panningTableL
 moveq  #0,panningTableR
 load   (panningTableL),panningTableL
 bset   #8,panningTableR
 add    panningTableL,panningTableR
 movei  #I2S_sample_voices,voiceTable
 moveq  #I2S_index_sample_vc_total,nextVoice
 shlq   #2,nextVoice
 moveta voiceTable,voiceTable
 moveta nextVoice,nextVoice

 move   panningDftLeft,r0
 move   panningDftLeft,r2
 add    panningTableL,r0
 add    panningTableR,r2
 loadb  (r0),r0
 loadb  (r2),r2

 move   panningDftRight,r1
 move   panningDftRight,r3
 add    panningTableL,r1
 add    panningTableR,r3
 loadb  (r1),r1
 loadb  (r3),r3
 moveq  #2,r4
initPanningLoop:
;;; #1
 store  r0,(voiceTable+I2S_index_sample_vc_panning_L)
 store  r2,(voiceTable+I2S_index_sample_vc_panning_R)
 add    nextVoice,voiceTable
;;; 2
 store  r1,(voiceTable+I2S_index_sample_vc_panning_L)
 store  r3,(voiceTable+I2S_index_sample_vc_panning_R)
 add    nextVoice,voiceTable
;;; 3
 store  r1,(voiceTable+I2S_index_sample_vc_panning_L)
 store  r3,(voiceTable+I2S_index_sample_vc_panning_R)
 add    nextVoice,voiceTable
;;; #4
 store  r0,(voiceTable+I2S_index_sample_vc_panning_L)
 subq   #1,r4
 store  r2,(voiceTable+I2S_index_sample_vc_panning_R)
 jr     ne,initPanningLoop
 add    nextVoice,voiceTable

;;; #9
 store  r0,(voiceTable+I2S_index_sample_vc_panning_L)
 store  r2,(voiceTable+I2S_index_sample_vc_panning_R)
 add    nextVoice,voiceTable
;;; 10
 store  r1,(voiceTable+I2S_index_sample_vc_panning_L)
 store  r3,(voiceTable+I2S_index_sample_vc_panning_R)
//-> add        nextVoice,voiceTable
;;; ----------------------------------------
;;; setup RM buffers

rm_buffer_int   equr    r27
rm_buffer_ext   equr    r26
buffer_offset   equr    r25
rm_channel_cnt  equr    r24
//->nextVoice   equr    r23
//->rm_mask             equr    r22
channel_cnt     equr    r21

 movefa voiceTable,voiceTable
 movefa nextVoice,nextVoice
 movei  #RM_buffers_main,rm_buffer_ext
 movei  #RM_buffers,rm_buffer_int
 moveq  #0,buffer_offset
 bset   #7+2,buffer_offset
 moveq  #max_RM_channels,rm_channel_cnt
 moveq  #max_NB_channels,channel_cnt
rm_init:
 shrq   #1,rm_mask
 move   rm_buffer_ext,r0
 jr     cc,rm_ext
 nop
 move   rm_buffer_int,r0
 subq   #1,rm_channel_cnt
 jr     ne,rm_set
 add    buffer_offset,rm_buffer_int
 jr     rm_set
 moveq  #0,rm_mask              ; all internal buffers use, switch to ext.

rm_ext:
 move   rm_buffer_ext,r0
 add    buffer_offset,rm_buffer_ext
rm_set:
 subq   #1,channel_cnt
 store  r0,(voiceTable+I2S_index_sample_vc_buffer_RM)
 jr     ne,rm_init
 add    nextVoice,voiceTable


; init Timer 1 = 50 HZ
 movei  #3643*2,R13
 div    multiplier,R13
 subq   #1,R13

; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
 movei  #JPIT1,r10
 movei  #(73-1)*65536,r12       ; Timer 1 Pre-scaler
 or     R13,R12
 store  r12,(r10)               ; JPIT1 & JPIT2

; enable interrupts
 movei  #D_FLAGS,r24
 movei  #D_I2SENA|D_TIM1ENA|REGPAGE,r29  ; I2S+Timer 1
 store  r29,(r24)
;------------------------------------------------------
;
; main lopop
;
;------------------------------------------------------

; ------------------------------
; decode stream AHX version bits

DSP_decode_bits_bits_to_read                     equr    R0
DSP_decode_bits_bits_resultat                    equr    R1
DSP_decode_bits_tmp0                             equr    R2
DSP_decode_bits_tmp1                             equr    R3
DSP_decode_bits_voice_counter                   equr    R4
DSP_decode_bits_flags_datas                      equr    R5
;                                                equr    R6
DSP_decode_bits_taille_d_un_record_datas_channel equr    R7
DSP_decode_bits_tmp2                             equr    R8
DSP_decode_bits_tmp3                             equr    R9
DSP_decode_bits_adresse_pointeur_lecture_bits    equr    R10
DSP_decode_bits_pointeur_lecture_bits            equr    R11
DSP_decode_bits_bitcount                         equr    R12 ; do not re-use!
;                                                equr    R13
DSP_decode_bits_datas_channels_destination       equr    R14
DSP_decode_bits_datas_I2S_destination            equr    R15
DSP_decode_bits_table_panning_voies              equr    R19
DSP_decode_bits_bitbuffer                        equr    R20 ; do not re-use!
DSP_decode_bits_read_bits_per_channel_loop       equr    R21
DSP_decode_bits_increment_datas_I2S_destination  equr    R22

DSP_decode_bits_readbits        .equr    R27
DSP_decode_bits_adresse_retour                      .equr    R28

 moveq  #0,DSP_decode_bits_bitcount ; force loading first word

 moveq  #1,r21
DSP_boucle_centrale:

DSP_boucle_centrale__wait_for_timer1_and_68000tick:
 cmpq   #3,R21    ; attente du timer 1
 jr     ne,DSP_boucle_centrale__wait_for_timer1_and_68000tick
 nop

; change la couleur de fond - debug
 .if  DISPLAY_TIME = 1
 moveq  #$f,r14
 shlq   #20,r14
 store r14,(r14+$58/4)
 .endif

 movei  #DSP_flag_replay_ON_OFF,R0
 load   (R0),R1
 movei  #DSP_sortie_finale,R2
 cmpq   #1,r1                   ; gracefull stop?
 jump   eq,(r2)
 cmpq   #5,r1                   ; pause?
 movei  #empty_i2s,r3
 jr     ne,no_pause
 cmpq   #6,r1
;;; pause song
 movei  #pause_music,r2
 jump   (r2)
 moveta r3,I2S_routine_actuelle

no_pause:
 jr     ne,no_new_song
 moveq  #5,r1
 movei  #restart_with_new_song,r2
 moveta r3,I2S_routine_actuelle
 jump   (r2)
 store  r1,(r0)                 ; new song starts paused

no_new_song:
 movei  #I2S_main_interrupt,r0
 moveta r0,I2S_routine_actuelle

 .if UPDATE_SONG_POS = 1
 movei  #DSP_localData,r14
 load   (r14+streamingbits_cur_index),r0
 load   (r14),r1
 sub    r1,r0
 movei  #DSP_stream_pos,r1
 store  r0,(r1)
 .endif

 movei  #I2S_sample_voices,DSP_decode_bits_datas_I2S_destination
 moveq  #I2S_index_sample_vc_total,DSP_decode_bits_increment_datas_I2S_destination
 shlq   #2,DSP_decode_bits_increment_datas_I2S_destination
 movei  #DSP_AHX_decode_streaming_V4_read_bits_from_bits_streaming,DSP_decode_bits_readbits
 movei  #DSP_module_streaming_bits_cur,DSP_decode_bits_adresse_pointeur_lecture_bits
 load   (DSP_decode_bits_adresse_pointeur_lecture_bits),DSP_decode_bits_pointeur_lecture_bits

; tester fin de stream = bouclage du stream
 movei  #DSP_module_streaming_bits_end,DSP_decode_bits_tmp0
 load   (DSP_decode_bits_tmp0),DSP_decode_bits_tmp0
 cmp    DSP_decode_bits_tmp0,DSP_decode_bits_pointeur_lecture_bits
 movei  #DSP_song,r14
 jr     cs,DSP_boucle_read_bits_per_channel__pas_fin_du_fichier
 load   (r14),r14
;;; restart
 load   (r14+song_restart_word/4),DSP_decode_bits_pointeur_lecture_bits
 add    r14,DSP_decode_bits_pointeur_lecture_bits
 load   (r14+song_restart_bit/4),DSP_decode_bits_bitcount
 addq   #song_header_size,DSP_decode_bits_pointeur_lecture_bits
 load   (DSP_decode_bits_pointeur_lecture_bits),DSP_decode_bits_bitbuffer
 addq   #4,DSP_decode_bits_pointeur_lecture_bits
 move   DSP_decode_bits_bitcount,DSP_decode_bits_voice_counter
 subq   #32,DSP_decode_bits_voice_counter
 sh     DSP_decode_bits_voice_counter,DSP_decode_bits_bitbuffer ; remove "used" bits

DSP_boucle_read_bits_per_channel__pas_fin_du_fichier:
 movei  #DSP_NB_channels,DSP_decode_bits_voice_counter
 load   (DSP_decode_bits_voice_counter),DSP_decode_bits_voice_counter

 movei  #DSP_HVL_table_panning_voies_de_base,DSP_decode_bits_table_panning_voies
 move   pc,DSP_decode_bits_read_bits_per_channel_loop
 addq   #4,DSP_decode_bits_read_bits_per_channel_loop
DSP_boucle_read_bits_per_channel:
 load    (DSP_decode_bits_table_panning_voies),DSP_decode_bits_datas_channels_destination

; read 8 flag bits
 moveq  #8,DSP_decode_bits_bits_to_read

 move   PC,DSP_decode_bits_adresse_retour
 jump   (DSP_decode_bits_readbits)
 addq   #6,DSP_decode_bits_adresse_retour

 move   DSP_decode_bits_bits_resultat,DSP_decode_bits_flags_datas

;--- 7
; vc_Pan : 8 bits
 movei  #DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_Pan,DSP_decode_bits_tmp0
 btst   #7,DSP_decode_bits_flags_datas
 move   PC,DSP_decode_bits_adresse_retour
 jump   eq,(DSP_decode_bits_tmp0)
 moveq  #8,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

; ici , convertir vc pan en ?
 moveq  #0,DSP_decode_bits_tmp1
 movei  #DSP_panning_table,DSP_decode_bits_tmp0
 load   (DSP_decode_bits_tmp0),DSP_decode_bits_tmp0
 bset   #8,DSP_decode_bits_tmp1
 add    DSP_decode_bits_tmp0,DSP_decode_bits_tmp1
 add    DSP_decode_bits_bits_resultat,DSP_decode_bits_tmp0
 add    DSP_decode_bits_bits_resultat,DSP_decode_bits_tmp1
 loadb  (DSP_decode_bits_tmp0),DSP_decode_bits_tmp0
 loadb  (DSP_decode_bits_tmp1),DSP_decode_bits_tmp1
 or     DSP_decode_bits_tmp0,DSP_decode_bits_tmp0
 or     DSP_decode_bits_tmp1,DSP_decode_bits_tmp1
 store  DSP_decode_bits_tmp0,(DSP_decode_bits_datas_I2S_destination+I2S_index_sample_vc_panning_L)
 store  DSP_decode_bits_tmp1,(DSP_decode_bits_datas_I2S_destination+I2S_index_sample_vc_panning_R)

;--- 6
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_Pan:
; vc_AudioVolume : 6 bits
 btst   #6,DSP_decode_bits_flags_datas
 move   PC,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_AudioVolume
 moveq  #6,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination) ;DSP_index_vc_AudioVolume

;--- 5
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_AudioVolume:
; vc_Waveform : 2 bits
 btst   #5,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_Waveform
 moveq  #2,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_Waveform)

;--- 4
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_Waveform:
; vc_SquarePos : 6 bits
 btst   #4,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_SquarePos
 moveq  #6,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_SquarePos)

;--- 3
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_SquarePos:
; vc_WaveLength : 3 bits
 btst   #3,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_WaveLength
 moveq  #3,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_WaveLength)

;--- 2
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_WaveLength:
; vc_FilterPos : 6 bits
 btst   #2,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_FilterPos
 moveq  #6,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_FilterPos)

;--- 1
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_FilterPos:
; vc_AudioPeriod : 12 bits
 btst   #1,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_AudioPeriod
 moveq  #12,DSP_decode_bits_bits_to_read

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_AudioPeriod)

;--- 0
DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_vc_AudioPeriod:
; Ring Modulation N/A
 btst   #0,DSP_decode_bits_flags_datas
 move   pc,DSP_decode_bits_adresse_retour
 jr     eq,DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_RM
 moveq  #1,DSP_decode_bits_bits_to_read

; en cas de RM, le bit est a 1 aussi si le RM vient d'etre coupé, dans ce cas là,
; vc_RingWaveform (1 bit) =0 + vc_RingAudioPeriod (12 bits) =0
; lecture vc_RingWaveform

 jump   (DSP_decode_bits_readbits)
 addq   #10,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_RingWaveform)

; lecture vc_RingAudioPeriod
 moveq  #12,DSP_decode_bits_bits_to_read
 move   pc,DSP_decode_bits_adresse_retour
 jump   (DSP_decode_bits_readbits)
 addq   #6,DSP_decode_bits_adresse_retour

 store  DSP_decode_bits_bits_resultat,(DSP_decode_bits_datas_channels_destination+DSP_index_vc_RingAudioPeriod)

DSP_AHX_decode_streaming_V2__boucle_voie__pas_de_RM:
; check si channel on, si off on met le volume à zéro
 load   (DSP_decode_bits_datas_channels_destination+DSP_index_vc_channel_on_off),DSP_decode_bits_flags_datas
 or     DSP_decode_bits_flags_datas,DSP_decode_bits_flags_datas
 jr     ne,DSP_read_bits__pas_channel_off
 moveq  #0,DSP_decode_bits_bits_to_read

 store  DSP_decode_bits_bits_to_read,(DSP_decode_bits_datas_channels_destination)

DSP_read_bits__pas_channel_off:
 subq   #1,DSP_decode_bits_voice_counter
 addqt  #4,DSP_decode_bits_table_panning_voies
 jump   ne,(DSP_decode_bits_read_bits_per_channel_loop)
 add    DSP_decode_bits_increment_datas_I2S_destination,DSP_decode_bits_datas_I2S_destination

 store  DSP_decode_bits_pointeur_lecture_bits,(DSP_decode_bits_adresse_pointeur_lecture_bits)

; FIN DE : decode stream AHX version bits
; ------------------------------

; --------------- code de gestion du AHX vers I2S ------------------------
; triangle and sawtooth : read N bytes ( wavelength)
;                         apply filter on N bytes
;                         apply volume on N bytes
;                        => buffer_temp_wave
; square : create 128 bytes
;                         apply filter on N bytes
;                         apply volume on N bytes
;                         source == des.
; noise : create 128 bytes
;                         apply filter on N bytes
;                         apply volume on N bytes
;                        => buffer_temp_wave ;
;
; 4 routines :
; - read wavelength bytes
; - apply filter on source/destination for N byte
; - appliquer le volume pour une source/dest sur N octets
; - square created 128 octets
; - noise  created 128 octets
; - volume=0 => buffer all zero

                                                  ; re-usable
DSP_create_wave_tmp0                   equr R0    ;-------------
DSP_create_wave_tmp1                   equr R1    ;-------------
DSP_create_wave_tmp2                   equr R2    ;-------------
DSP_create_wave_tmp3                   equr R3    ;-------------
DSP_create_wave_tmp4                   equr R4    ;-------------
DSP_create_wave_tmp5                   equr R5    ;-------------
DSP_create_wave_ratio_amiga_jaguar     equr R6    ;  si necessaire
DSP_create_wave_wavelength_in_bytes    equr R7    ;   NO
DSP_create_wave_byte_read_increment    equr R8    ;   NO
DSP_create_wave_channel_count          equr R9    ;   NO
DSP_create_wave_volume                 equr R10   ;   NO
DSP_create_wave_wavelength             equr R11   ;   NO
;;; r12
DSP_create_wave_filterpos              equr R13   ;   NO
DSP_create_wave_source_datas_channel   equr R14   ;   NO
DSP_create_wave_dest_record_I2S        equr R15   ;   NO
DSP_create_wave_decaleur_wavelength    equr R16   ;   YES
DSP_create_wave_mask_for_I2S           equr R17   ;   NO
DSP_create_wave_waveform               equr R18   ;   NO
DSP_create_wave_squarepos              equr R19   ;   NO
;;; r20
DSP_create_wave_routines_a_executer    equr R21   ;  si necessaire
DSP_create_wave_tmp6                   equr R22   ;-------------
DSP_create_wave_tmp7                   equr R23   ;-------------
DSP_create_wave_filter_length_in_bytes equr R24   ;   NO
DSP_create_wave_tmp9                   equr R25   ;-------------
DSP_create_wave_tmp8                   equr R26   ;-------------
DSP_create_wave_channel_loop           equr R27   ;   NO
DSP_GENERE_WAVE_ROUTINE_VOLUME_A_ZERO  equr R28   ;  si necessaire
DSP_next_stage_address                 equr R29   ;   NO
DSP_create_wave_increment_RM_for_I2S   equr R30   ;   NO

 movei  #I2S_sample_voices,DSP_create_wave_dest_record_I2S
 movei  #HIVELY_datas_channels,DSP_create_wave_source_datas_channel
 movei  #DSP_ratio_Amiga_Jaguar__a_virgule_9_bits,DSP_create_wave_ratio_amiga_jaguar
 movei  #DSP_NB_channels,DSP_create_wave_channel_count
 load   (DSP_create_wave_channel_count),DSP_create_wave_channel_count

 movei  #DSP_create_wave_set_volume_zero,DSP_GENERE_WAVE_ROUTINE_VOLUME_A_ZERO
 load   (DSP_create_wave_ratio_amiga_jaguar),DSP_create_wave_ratio_amiga_jaguar
 movei  #AHX_table_routines_a_executer,DSP_create_wave_routines_a_executer

 move   pc,DSP_create_wave_channel_loop
 addq   #4,DSP_create_wave_channel_loop
DSP_create_wave_boucle:
//-> load   (DSP_create_wave_source_datas_channel+DSP_index_vc_AudioVolume),DSP_create_wave_volume
 load   (DSP_create_wave_source_datas_channel),DSP_create_wave_volume
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_Waveform),DSP_create_wave_waveform
 cmpq   #0,DSP_create_wave_volume
 jump   eq,(DSP_GENERE_WAVE_ROUTINE_VOLUME_A_ZERO)
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_SquarePos),DSP_create_wave_squarepos
 ; = wavelength : 0 à 5 ( 2^(n+2) ) // $04/$08/$10/$20/$40/$80  0=$04, 1=$08, 2=$10, 3=$20, 4=$40, 5=$80
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_WaveLength),DSP_create_wave_wavelength
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_FilterPos),DSP_create_wave_filterpos
 move   DSP_create_wave_wavelength,DSP_create_wave_decaleur_wavelength

 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_AudioPeriod),DSP_create_wave_tmp0 ;DSP_create_wave_audioperiod
 subq   #5,DSP_create_wave_decaleur_wavelength
 moveq  #1,DSP_create_wave_byte_read_increment
 addq   #2,DSP_create_wave_wavelength   ; wavelength + 2
 sh     DSP_create_wave_decaleur_wavelength,DSP_create_wave_byte_read_increment
 moveq  #1,DSP_create_wave_wavelength_in_bytes
 neg    DSP_create_wave_wavelength

 move   DSP_create_wave_ratio_amiga_jaguar,DSP_create_wave_tmp6
 sh     DSP_create_wave_wavelength,DSP_create_wave_wavelength_in_bytes
 div    DSP_create_wave_tmp0,DSP_create_wave_tmp6
 or     DSP_create_wave_tmp6,DSP_create_wave_tmp6
 move   DSP_create_wave_waveform,DSP_create_wave_tmp0

 store  DSP_create_wave_tmp6,(DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_increment)
 movei  #buffer_temp_wave,DSP_create_wave_tmp6                    ;dest pour triangle et sawtooth, variaiblisé pour gérer le RM
 shlq   #2,DSP_create_wave_tmp0    ; waveform * 4
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_mask_for_I2S
 add    DSP_create_wave_routines_a_executer,DSP_create_wave_tmp0      ; choix de la routine suivant waveform
 movei  #AHX_main_routine_filter,DSP_next_stage_address
 load   (DSP_create_wave_tmp0),DSP_create_wave_tmp0
 subq   #1,DSP_create_wave_mask_for_I2S    ; mask pour I2S
 jump   (DSP_create_wave_tmp0)
 shlq   #AHX_nb_bits_virgule_increment_period,DSP_create_wave_mask_for_I2S   ; avec virgule

AHX_main_adresse_retour_vers_main_suivant_voie:
; gestion de Ring Modulation
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_RingAudioPeriod),DSP_create_wave_increment_RM_for_I2S
 move   DSP_create_wave_ratio_amiga_jaguar,DSP_create_wave_tmp0
 cmpq   #0,DSP_create_wave_increment_RM_for_I2S
 load   (DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_buffer_RM),DSP_create_wave_tmp6    ; buffer dest = buffer RM
 jr     eq,DSP_create_wave_boucle__apres_RM
 div    DSP_create_wave_increment_RM_for_I2S,DSP_create_wave_tmp0
; buffer dans DSP_create_wave_tmp6
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_RingWaveform),DSP_create_wave_tmp1
 shlq   #2,DSP_create_wave_tmp1    ; RM waveform * 4

 ; choix de la routine suivant waveform pour RM : 0 ou 1
 add    DSP_create_wave_routines_a_executer,DSP_create_wave_tmp1

 load   (DSP_create_wave_tmp1),DSP_create_wave_tmp1
 move   DSP_create_wave_tmp0,DSP_create_wave_increment_RM_for_I2S

 move   pc,DSP_next_stage_address
 jump   (DSP_create_wave_tmp1)
 addq   #6,DSP_next_stage_address

DSP_create_wave_boucle__apres_RM:
 store  DSP_create_wave_increment_RM_for_I2S,(DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_increment_RM)
 store  DSP_create_wave_mask_for_I2S,(DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_loop_mask)

DSP_create_wave_boucle_recolle1:
 moveq  #DSP_index_vc_total,DSP_create_wave_tmp0
 shlq   #2,DSP_create_wave_tmp0
 moveq  #I2S_index_sample_vc_total,DSP_create_wave_tmp1
 shlq   #2,DSP_create_wave_tmp1
 add    DSP_create_wave_tmp0,DSP_create_wave_source_datas_channel
 subq   #1,DSP_create_wave_channel_count
 jump   ne,(DSP_create_wave_channel_loop)
 add    DSP_create_wave_tmp1,DSP_create_wave_dest_record_I2S

pause_music:
 if READ_PAD = 1
;-------------------------------------------------------------------------------
;         Gestion du PAD
;-------------------------------------------------------------------------------
;DSP_pad1
;DSP_pad2
; Pads : mask = xxxx xxCx xxBx 2580 147* oxAP 369# RLDU
; usage : R0 à R11
 movei  #JOYSTICK,R0

 moveq  #15,r2
 moveq  #%00000000000000000000000000000011,R3  ; mask port 1
 shlq   #24,r2                                 ; $0f00.0000
 move   r2,r5
 move   r3,r6

; row 0
 MOVEI  #$817e,R1
 shlq   #4,r5                            ; mask port 2
 storew R1,(R0)         ; lecture row 0
 shlq   #2,r6                            ; mask port 2
 load   (R0),R1

; row0 = Pause A Up Down Left Right
; 0000 1111 0000 0000 0000 0000 0000 0011
;      RLDU                            Ap
 move   R1,R10    ; stocke pour lecture port 2

 move   R1,R4
 move   R10,R7
 and    R3,R4
 and    R6,R7
 and    R2,R1
 and    R5,R10
 shlq   #8,R4    ; R4=Ap xxxx xxxx
 shlq   #6,R7    ; R7=Ap xxxx xxxx
 shrq   #24,R1    ; R1=RLDU
 shrq   #28,R10   ; R10=RLDU

; row 1
 MOVEI  #$81BD,R11
 or     R4,R1
 storew R11,(R0)    ; lecture row 1
 or     R7,R10
 load   (R0),R8
; row1 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      147*                            BD
 move   R8,R9    ; stocke pour lecture port 2
;row1 port 1&2

 move   R8,R4
 move   R9,R7
 and    R3,R4
 and    R6,R7
 shlq   #20,R4
 shlq   #18,R7
 and    R2,R8
 and    R5,R9
 shrq   #12,R8    ; R8=147*
 shrq   #16,R9    ; R9=147*
 or     R8,R4
 or     R7,R9

; row 2
 addq   #30,r11                 ; $81db
 or     R4,R1    ; R1= BD xxxx 147* xxAp xxxx RLDU
 storew R11,(R0)    ; lecture row 2
 or     R9,R10
 load   (R0),R8
 move   R8,R9    ; stocke pour lecture port 2

; row2 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      2580                            CE
; 24,8,22,12
 move   R8,R4
 move   R9,R7
 and    R3,R4
 and    R6,R7
 shlq   #24,R4
 shlq   #22,R7
 and    R2,R8
 and    R5,R9
 shrq   #8,R8    ; R8=147*
 shrq   #12,R9   ; R9=147*
 or     R8,R4
 or     R7,R9
; row 3
 addq   #12,r11                 ;$81e7
 or     R4,R1    ; R1= BD xxxx 147* xxAp xxxx RLDU
 storew R11,(R0)    ; lecture row 3
 or     R9,R10

 load  (R0),R8
; row3 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      369#                            oF
; l10,r20,l8,r24
 move   R8,R9    ; stocke pour lecture port 2

 move   R8,R4
 move   R9,R7
 and    R3,R4
 and    R6,R7
 shlq   #10,R4
 shlq   #8,R7
 and    R2,R8
 and    R5,R9
 shrq   #20,R8    ; R8=147*
 shrq   #24,R9    ; R9=147*
 or     R8,R4
 or     R7,R9
 or     R4,R1    ; R1= BD xxxx 147* xxAp xxxx RLDU
 or     R9,R10

 movei  #~$fcc00000,r0
 movei  #DSP_pad1,R2
 not    R1
 not    R10
 and    r0,r1
 and    r0,r10
 store  R1,(R2)
 addq   #4,r2
 store  R10,(r2)
;-------------------------------------------------------------------------------
;         FIN - Gestion du PAD
;-------------------------------------------------------------------------------
 .endif
;-------------------------------------------------------------------------------
; change la couleur de fond - debug
 .if  DISPLAY_TIME = 1
 moveq  #0,r0
 moveq  #$f,r14
 shlq   #20,r14
 store r0,(r14+$58/4)
 .endif
; ------------------------------
; retour boucle principale
; bouclage final

 movei  #DSP_boucle_centrale,R0
 jump   (R0)
 moveq  #1,R21

; sortie finale, extinction du DSP
DSP_sortie_finale:
; R0 = DSP_flag_replay_ON_OFF

__pc:
 move pc,r1
 addq #DSP_AHX_routine_interruption_I2S_shutdown_now__real_shutdown-__pc,r1
 moveta R1,I2S_routine_actuelle
DSP_sortie_finale__wait_for_timer1:
 load   (R0),R1
 cmpq   #3,R1
 jr     ne,DSP_sortie_finale__wait_for_timer1
 moveq  #4,R2

 store  r2,(r0)
 movei  #D_CTRL,R0
 moveq  #0,R1
.wait:
 jr     .wait
 store  R1,(R0)

DSP_AHX_routine_interruption_I2S_shutdown_now__real_shutdown:
 movei  #DSP_flag_replay_ON_OFF,I2S_tmp_3
 moveq  #2,I2S_tmp_2
 bclr   #3,I2S_save_flags       ; clear IMASK
 store  I2S_tmp_2,(I2S_tmp_3)   ; ask timer 1 to stop = 2
 bset   #10,I2S_save_flags      ; clear latch 1 = I2S
 load   (r31),I2S_tmp_1         ; return address
 bclr   #5,I2S_save_flags       ; clear I2S enabled => stop I2S
 addqt  #2,I2S_tmp_1            ; next instruction
 addqt  #4,r31                  ; pop from stack
 jump   (I2S_tmp_1)             ; return
 store  I2S_save_flags,(R30)    ; restore flags

;-------------------------------------------------------------------------------
;
;
; subroutines to fill the sample buffers
;
;
;-------------------------------------------------------------------------------

; ----------------
; triangle

AHX_DSP_fill_buffer_triangle:
; 3 loops
 move   DSP_create_wave_byte_read_increment,DSP_create_wave_tmp1
 moveq  #0,DSP_create_wave_tmp5
 shlq   #2,DSP_create_wave_tmp1

; loop 1
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp2 ; counter -4
AHX_DSP_fill_buffer_triangle_loop1:
 store  DSP_create_wave_tmp5,(DSP_create_wave_tmp6)
 subq   #4,DSP_create_wave_tmp2
 addqt  #4,DSP_create_wave_tmp6
 jr     ne,AHX_DSP_fill_buffer_triangle_loop1
 add    DSP_create_wave_tmp1,DSP_create_wave_tmp5

; loop 2
 movei  #127,DSP_create_wave_tmp4
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp2 ; counter -2
AHX_DSP_fill_buffer_triangle_loop2:
 cmp    DSP_create_wave_tmp4,DSP_create_wave_tmp5
 move   DSP_create_wave_tmp5,DSP_create_wave_tmp3
 jr     mi,AHX_DSP_fill_buffer_triangle_loop2_test80
 subq   #2,DSP_create_wave_tmp2
 move   DSP_create_wave_tmp4,DSP_create_wave_tmp3

AHX_DSP_fill_buffer_triangle_loop2_test80:
 store  DSP_create_wave_tmp3,(DSP_create_wave_tmp6)

 addqt  #4,DSP_create_wave_tmp6
 jr     ne,AHX_DSP_fill_buffer_triangle_loop2
 sub    DSP_create_wave_tmp1,DSP_create_wave_tmp5

 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp2 ; counter -4
AHX_DSP_fill_buffer_triangle_loop3:
 store  DSP_create_wave_tmp5,(DSP_create_wave_tmp6)
 subq   #4,DSP_create_wave_tmp2
 addqt  #4,DSP_create_wave_tmp6
 jr     ne,AHX_DSP_fill_buffer_triangle_loop3
 add    DSP_create_wave_tmp1,DSP_create_wave_tmp5

 move   DSP_next_stage_address,DSP_create_wave_tmp1
 movei  #AHX_main_routine_volume,DSP_next_stage_address
 jump   (DSP_create_wave_tmp1)
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_filter_length_in_bytes

; ----------------
; sawtooth

AHX_DSP_fill_buffer_sawtooth:

; increment = AHX_main_increment_pour_lire_les_octets
 move   DSP_create_wave_byte_read_increment,DSP_create_wave_tmp1
 movei  #$FFFFFF80,DSP_create_wave_tmp2
 add    DSP_create_wave_tmp1,DSP_create_wave_tmp1

 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp3
AHX_DSP_fill_buffer_sawtooth_generation_and_selection:
 store  DSP_create_wave_tmp2,(DSP_create_wave_tmp6)
 subq   #1,DSP_create_wave_tmp3
 addqt  #4,DSP_create_wave_tmp6
 jr     ne,AHX_DSP_fill_buffer_sawtooth_generation_and_selection
 add    DSP_create_wave_tmp1,DSP_create_wave_tmp2

 move   DSP_next_stage_address,DSP_create_wave_tmp1
 movei  #AHX_main_routine_volume,DSP_next_stage_address
 jump   (DSP_create_wave_tmp1)
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_filter_length_in_bytes

; ----------------
; square

AHX_DSP_fill_buffer_square:
 moveq  #0,DSP_create_wave_tmp5
 moveq  #31,DSP_create_wave_tmp3
 bset   #7,DSP_create_wave_tmp5                 ; 128

; relatif a wavelength
; R19 = -(5-wavelength) // R0 = squarepos
 sh     DSP_create_wave_decaleur_wavelength,DSP_create_wave_squarepos

; 32-(abs(position-32)) -1   : de 0 a 31
 subq   #32,DSP_create_wave_squarepos
 movei  #buffer_temp_wave,DSP_create_wave_tmp1          ; buffer dest 1
 abs    DSP_create_wave_squarepos
 move   DSP_create_wave_tmp5,DSP_create_wave_tmp6       ; 128
 move   DSP_create_wave_tmp5,DSP_create_wave_tmp2       ; 128
 sub    DSP_create_wave_squarepos,DSP_create_wave_tmp3  ; = 0..31
 subqt  #2,DSP_create_wave_tmp2                         ; 126
 jr     pl,.ok_positif_ou_zero
 neg    DSP_create_wave_tmp6                            ; -128
 moveq  #0,DSP_create_wave_tmp3

.ok_positif_ou_zero:
 move  DSP_create_wave_tmp3,DSP_create_wave_squarepos

; 0 : 126*-128//2*127
; 1 : 124*-128//4*127
; 31 : 64*-128//64*127
; nb -128 = 126-(2*nb) = R12
; nb 127 = 128 - (nb de 128) = R14

; initial counter = -126 to -64
 add    DSP_create_wave_tmp3,DSP_create_wave_tmp3       ; * 2
 move   DSP_create_wave_tmp1,DSP_create_wave_tmp4       ; buffer dest 2
 sub    DSP_create_wave_tmp3,DSP_create_wave_tmp2       ; 126-(2*[0..31] ) : 126 à 64
 addqt  #4,DSP_create_wave_tmp4                         ; 2nd buffer = +4
 sub    DSP_create_wave_tmp2,DSP_create_wave_tmp5

AHX_DSP_fill_buffer_square_loop_minus_128:
 store  DSP_create_wave_tmp6,(DSP_create_wave_tmp1)
 store  DSP_create_wave_tmp6,(DSP_create_wave_tmp4)
 subq   #2,DSP_create_wave_tmp2
 addqt  #8,DSP_create_wave_tmp1
 jr     ne,AHX_DSP_fill_buffer_square_loop_minus_128
 addqt  #8,DSP_create_wave_tmp4

 not    DSP_create_wave_tmp6                            ; tmp6 = 127

AHX_DSP_fill_buffer_square_loop_plus_127:
 store  DSP_create_wave_tmp6,(DSP_create_wave_tmp1)
 store  DSP_create_wave_tmp6,(DSP_create_wave_tmp4)
 subq   #2,DSP_create_wave_tmp5
 addqt  #8,DSP_create_wave_tmp1
 jr     ne,AHX_DSP_fill_buffer_square_loop_plus_127
 addqt  #8,DSP_create_wave_tmp4

; jump to filter
 movei  #AHX_main_routine_filter,DSP_create_wave_tmp1
 movei  #AHX_main_routine__lire_N_octets,DSP_next_stage_address
 jump   (DSP_create_wave_tmp1)
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_filter_length_in_bytes

; ----------------
; noise

AHX_DSP_fill_buffer_noise:
//-> moveq  #0,DSP_create_wave_wavelength_in_bytes
//-> bset   #7,DSP_create_wave_wavelength_in_bytes

 movei  #(($80-1)<<AHX_nb_bits_virgule_increment_period),DSP_create_wave_mask_for_I2S    ; force le mask en accord avec le nb d'octets
 movei  #buffer_temp_wave,DSP_create_wave_tmp8
 movei  #AHX_DSP_Seed_Noise,DSP_create_wave_tmp6
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp4
 moveq  #%00011010,DSP_create_wave_tmp7
 bset   #7,DSP_create_wave_tmp7                         ; %10011010
 load   (DSP_create_wave_tmp6),DSP_create_wave_tmp3     ;current seed
 movei  #$ffffff80,DSP_create_wave_tmp0

 move   pc,DSP_create_wave_tmp2
 addq   #4,DSP_create_wave_tmp2

AHX_DSP_fill_buffer_noise_loop:
 btst   #8,DSP_create_wave_tmp3
 move   DSP_create_wave_tmp3,DSP_create_wave_tmp5
 jr     eq,AHX_routine_Main_noise_lower
 btst   #15,DSP_create_wave_tmp3

 jr     ne,AHX_routine_Main_noise_fixed
 move   DSP_create_wave_tmp0,DSP_create_wave_tmp5     ; = -128

 neg    DSP_create_wave_tmp5     ; $7F

AHX_routine_Main_noise_lower:
 shlq   #24,DSP_create_wave_tmp5
 sharq  #24,DSP_create_wave_tmp5

AHX_routine_Main_noise_fixed:
 rorq   #5,DSP_create_wave_tmp3
 xor    DSP_create_wave_tmp7,DSP_create_wave_tmp3
 store  DSP_create_wave_tmp5,(DSP_create_wave_tmp8)
 move   DSP_create_wave_tmp3,DSP_create_wave_tmp1
 rorq   #32-2,DSP_create_wave_tmp3
 addqt  #4,DSP_create_wave_tmp8
 add    DSP_create_wave_tmp3,DSP_create_wave_tmp1
 shlq   #16,DSP_create_wave_tmp1
 shrq   #16,DSP_create_wave_tmp1 ; & $ffff
 xor    DSP_create_wave_tmp1,DSP_create_wave_tmp3
 subq   #1,DSP_create_wave_tmp4
 jump   ne,(DSP_create_wave_tmp2)
 rorq   #3,DSP_create_wave_tmp3

//-> movei  #AHX_main_routine_filter,DSP_create_wave_tmp0  ; fall thru
 movei  #AHX_main_routine_volume,DSP_next_stage_address
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_filter_length_in_bytes   ; =128
//-> jump   (DSP_create_wave_tmp0)
 store  DSP_create_wave_tmp3,(DSP_create_wave_tmp6)    ; save seed
; ----------------
AHX_main_routine_filter:
; appliquer le filtre de dest sur dest
 ; tester si filterpos = 32 ?
 ; filterpos de 1 a 31 / 32 / 33 a 63 : 1 a 63 : si on fait -32 : de -31 a -1 / 0 / 1 a 31    // AND $1F : -1 and 31=1 / -30 => 2 / 0 / 1 a 31
 ; OK calculer freq = 25 + ( 9 * filterpos )
 ; calculer position de low dans binPrecalcTable
 ; lire mid et low
 ; sur AHX_main_wavelength_en_octets__pour_filtre octets

;reg_AHX_filter_filterpos          .equr  R0    ; OK
reg_AHX_filter_filterpos_and_1F .equr  R1    ; OK
reg_AHX_filter_source_low       .equr  R3    ; OK
; double volontaire
reg_AHX_filter_R3               .equr  R3    ; OK
reg_AHX_filter_source_mid       .equr  R4    ; OK

reg_AHX_filter_R5               .equr  R5    ; OK
reg_AHX_filter_R22              .equr  R22   ; OK
reg_AHX_filter_R23              .equr  R23   ; OK
reg_AHX_filter_tmp_buffer_ptr   .equr  R30   ; OK
reg_AHX_filter_loop             .equr  R31   ; OK
reg_AHX_filter_freq             .equr  R16   ; OK

AHX_main_filtre_in              .equr  R1    ; OK
AHX_main_filtre_high            .equr  R2    ; OK
AHX_main_filtre_fre             .equr  R5    ; OK
AHX_main_filtre_low             .equr  R25   ; OK
AHX_main_filtre_mid             .equr  R26   ; OK

;   remplacer R8 et R9 et R16

; relit :
;   - pvt_filterPos    R13
;   - pvt_Waveform    R18
;   - pvt_Wavelength   R11
;   -

 ; = wavelength : 0 à 5 ( 2^(n+2) ) // $04/$08/$10/$20/$40/$80  0=$04, 1=$08, 2=$10, 3=$20, 4=$40, 5=$80
 subq   #32,DSP_create_wave_filterpos
 load   (DSP_create_wave_source_datas_channel+DSP_index_vc_WaveLength),DSP_create_wave_wavelength
 jump   eq,(DSP_next_stage_address) ; no filter
 moveq  #31,reg_AHX_filter_filterpos_and_1F

; il y a un filtre
 and    DSP_create_wave_filterpos,reg_AHX_filter_filterpos_and_1F   ; filterpos & $1F : 1 a 31
 movei  #DSP_filterPreCalcTable,reg_AHX_filter_source_low
 load   (reg_AHX_filter_source_low),reg_AHX_filter_source_low
 subq   #1,reg_AHX_filter_filterpos_and_1F          ; filterpos : 0 a 30
 moveq  #(45*2)/9,reg_AHX_filter_R5
 movei  #((31*(6+6+$20+1))*2),reg_AHX_filter_source_mid
 move   reg_AHX_filter_filterpos_and_1F,reg_AHX_filter_R22

 moveq  #9,reg_AHX_filter_freq
 mult   reg_AHX_filter_freq,reg_AHX_filter_R5
 mult   reg_AHX_filter_R5,reg_AHX_filter_R22           ; R6 = filterpos ( 0 a 30) * 45
 mult   reg_AHX_filter_filterpos_and_1F,reg_AHX_filter_freq   ; freq = filterpos * 9
 add    reg_AHX_filter_R22,reg_AHX_filter_source_low
 addq   #25,reg_AHX_filter_freq     ; freq = 25+(9*filterpos)

 ; tester pvt_Waveform
 ; 0=triangle / 1=sawtooth / 2=square / 3=noise
 ; si = 0 : + pvt_Wavelength*2
 ; si = 1 : + (6*2) + pvt_Wavelength*2
 ; si = 2 : + (6*2)*2 + pvt_squarePos mais ramené à : 0 à 31 = R18
 ; si = 3 : + (6+6+$20)*2

 cmpq   #1,DSP_create_wave_waveform
 move   DSP_create_wave_waveform,reg_AHX_filter_R22
 jr     hi,AHX_DSP_fill_buffer_filter__pas_triangle_ni_sawtooth
 cmpq   #3,reg_AHX_filter_R22

; triangle ou sawtooth
 ;movei  #pvt_Wavelength,reg_AHX_filter_R5
 ;add   AHX_main_pointeur_sur_enregistrement_voice,reg_AHX_filter_R5
 ;loadb  (reg_AHX_filter_R5),reg_AHX_filter_R23
 move   DSP_create_wave_wavelength,reg_AHX_filter_R23
 add    reg_AHX_filter_R23,reg_AHX_filter_R23        ; wavelength*2
 cmpq   #0,reg_AHX_filter_R22
 jr     eq,AHX_DSP_fill_buffer_filter__calcul_filtre
 add    reg_AHX_filter_R23,reg_AHX_filter_source_low   ; source low OK

; sawtooth : + (6*2) + pvt_Wavelength*2
 jr     AHX_DSP_fill_buffer_filter__calcul_filtre
 addqt  #(6*2),reg_AHX_filter_source_low

AHX_DSP_fill_buffer_filter__pas_triangle_ni_sawtooth:
; square ou noise
;;->  cmpq  #3,reg_AHX_filter_R22 ; done above
 jr     ne,AHX_DSP_fill_buffer_filter__square
; noise : 45*(filterpos-1)+     (6+6+$20)*2
 moveq  #((6+6+$20)*2)/4,reg_AHX_filter_R5
 shlq   #2,reg_AHX_filter_R5

 jr     AHX_DSP_fill_buffer_filter__calcul_filtre
 add    reg_AHX_filter_R5,reg_AHX_filter_source_low

AHX_DSP_fill_buffer_filter__square:
; noise : + (6*2)*2 + pvt_squarePos mais ramené à : 0 à 31 = R18
 add    DSP_create_wave_squarepos,DSP_create_wave_squarepos   ; * 2 pour .word
 addq   #((6*2)*2),reg_AHX_filter_source_low
 add    DSP_create_wave_squarepos,reg_AHX_filter_source_low

AHX_DSP_fill_buffer_filter__calcul_filtre:
 add    reg_AHX_filter_source_low,reg_AHX_filter_source_mid

; mid and low sources are reversed
 loadw  (reg_AHX_filter_source_low),AHX_main_filtre_mid
 movei  #$FF800000,reg_AHX_filter_R22

 loadw  (reg_AHX_filter_source_mid),AHX_main_filtre_low
 move   reg_AHX_filter_R22,reg_AHX_filter_R23
 shlq   #16,AHX_main_filtre_low
 not    reg_AHX_filter_R23              //-> movei  #$007F0000
 shlq   #16,AHX_main_filtre_mid
 sharq  #8,AHX_main_filtre_low
 sharq  #8,AHX_main_filtre_mid   ; ext.l + asl.l #8
 movei  #buffer_temp_wave,reg_AHX_filter_tmp_buffer_ptr

 move   pc,reg_AHX_filter_loop
 addq   #4,reg_AHX_filter_loop
;----------- filter loop ------------
AHX_main_routine_filter_loop:
 moveq  #0,AHX_main_filtre_high
 load   (reg_AHX_filter_tmp_buffer_ptr),AHX_main_filtre_in  ; valeur sur 8 bits signée
 sub    AHX_main_filtre_mid,AHX_main_filtre_high
 shlq   #24,AHX_main_filtre_in
 sub    AHX_main_filtre_low,AHX_main_filtre_high
 sharq  #8,AHX_main_filtre_in      ; 32 bits signée << 16
 add    AHX_main_filtre_in,AHX_main_filtre_high

; clip  AHX_main_filtre_high between $FF80 and $007F
 cmp    reg_AHX_filter_R22,AHX_main_filtre_high
 jr     pl,AHX_main_routine_filter__high__superieur_au_minimum
 cmp    reg_AHX_filter_R23,AHX_main_filtre_high
 move   reg_AHX_filter_R22,AHX_main_filtre_high
;;;  if high < minimum then not > maximum
AHX_main_routine_filter__high__superieur_au_minimum:
 jr     mi,AHX_main_routine_filter__high__inferieur_au_maximum
 nop
 move   reg_AHX_filter_R23,AHX_main_filtre_high

AHX_main_routine_filter__high__inferieur_au_maximum:
; fre  = (high >> 8) * freq;
 move   AHX_main_filtre_high,AHX_main_filtre_fre
 sharq  #8,AHX_main_filtre_fre
 imult  reg_AHX_filter_freq,AHX_main_filtre_fre

; mid = mid + fre
 add    AHX_main_filtre_fre,AHX_main_filtre_mid
; clipper  AHX_main_filtre_mid entre $FF80 et $007F
 cmp    reg_AHX_filter_R22,AHX_main_filtre_mid
 jr     pl,AHX_main_routine_filter__mid__superieur_au_minimum
 cmp    reg_AHX_filter_R23,AHX_main_filtre_mid
 move   reg_AHX_filter_R22,AHX_main_filtre_mid
;;;  if mid < minimum then not > maximum
AHX_main_routine_filter__mid__superieur_au_minimum:
 jr     mi,AHX_main_routine_filter__mid__inferieur_au_maximum
 nop
 move   reg_AHX_filter_R23,AHX_main_filtre_mid
AHX_main_routine_filter__mid__inferieur_au_maximum:

; fre  = (mid  >> 8) * freq;
 move   AHX_main_filtre_mid,AHX_main_filtre_fre
 sharq  #8,AHX_main_filtre_fre
 imult  reg_AHX_filter_freq,AHX_main_filtre_fre

; low = low + fre
 add    AHX_main_filtre_fre,AHX_main_filtre_low

; clipper  AHX_main_filtre_low entre $FF80 et $007F
 cmp    reg_AHX_filter_R22,AHX_main_filtre_low
 jr     pl,AHX_main_routine_filter__low__superieur_au_minimum
 cmp    reg_AHX_filter_R23,AHX_main_filtre_low
 move   reg_AHX_filter_R22,AHX_main_filtre_low
;;;  if low < minimum then not > maximum
AHX_main_routine_filter__low__superieur_au_minimum:
 jr     mi,AHX_main_routine_filter__low__inferieur_au_maximum
; choisis si on met low ou high en fonction de filterpos
 cmpq   #0,DSP_create_wave_filterpos

 move   reg_AHX_filter_R23,AHX_main_filtre_low
AHX_main_routine_filter__low__inferieur_au_maximum:

; choisis si on met low ou high en fonction de filterpos
 move   AHX_main_filtre_high,reg_AHX_filter_R3 ;; store high
 jr     pl,AHX_main_routine_filter__store_done
 nop
; filterpos negative : store low
 move   AHX_main_filtre_low,reg_AHX_filter_R3
AHX_main_routine_filter__store_done:
 sharq  #16,reg_AHX_filter_R3
 subq   #1,DSP_create_wave_filter_length_in_bytes
 store  reg_AHX_filter_R3,(reg_AHX_filter_tmp_buffer_ptr)
 jump   ne,(reg_AHX_filter_loop)
 addqt  #4,reg_AHX_filter_tmp_buffer_ptr

; sortie
 jump   (DSP_next_stage_address)
 nop

; ----------------
AHX_main_routine__lire_N_octets:
; dispo : DSP_create_wave_tmp0
; dispo : DSP_create_wave_tmp4
; dispo : DSP_create_wave_tmp7
; lire  AHX_main_wavelength_en_octets octets
;   increment entre les octets = AHX_main_increment_pour_lire_les_octets
;   source = AHX_main_source_des_samples
;   dest = AHX_main_buffer_dest_des_samples
; saut en AHX_main_pointeur_adresse_routine_etape_2 à la fin
 movei  #buffer_temp_wave,DSP_create_wave_tmp1
 move   DSP_create_wave_byte_read_increment,DSP_create_wave_tmp6
 move   DSP_create_wave_tmp1,DSP_create_wave_tmp2
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp5
 shlq   #2,DSP_create_wave_tmp6    ; ecart entre les octets * 4
AHX_main_routine_byte_read_loop:
 load   (DSP_create_wave_tmp1),DSP_create_wave_tmp3
 add    DSP_create_wave_tmp6,DSP_create_wave_tmp1
 subq   #1,DSP_create_wave_tmp5
 store  DSP_create_wave_tmp3,(DSP_create_wave_tmp2)
 jr     ne,AHX_main_routine_byte_read_loop
 addqt  #4,DSP_create_wave_tmp2

; forcement volume juste après
 ;movei #AHX_main_routine_volume,DSP_create_wave_tmp1
 ;move  DSP_next_stage_address_plus_1,DSP_next_stage_address
 ;move  DSP_next_stage_address_plus_2,DSP_next_stage_address_plus_1
 ;jump  (DSP_create_wave_tmp1)
 ;nop
; ----------------
AHX_main_routine_volume:
; appliquer le volume de dest sur dest // AHX_main_wavelength_en_octets
 movei  #buffer_temp_wave,DSP_create_wave_tmp1
 move   DSP_create_wave_wavelength_in_bytes,DSP_create_wave_tmp8
 move   DSP_create_wave_volume,DSP_create_wave_tmp0
 load   (DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_buffer),DSP_create_wave_tmp5
 move   DSP_create_wave_tmp1,DSP_create_wave_tmp2
 movei  #$FFFF,DSP_create_wave_tmp9
 addq   #4,DSP_create_wave_tmp2

AHX_main_volume_loop:
 load   (DSP_create_wave_tmp1),DSP_create_wave_tmp3     ; octet 1
 load   (DSP_create_wave_tmp2),DSP_create_wave_tmp4     ; octet 2
 imult  DSP_create_wave_volume,DSP_create_wave_tmp3     ; * volume
 imult  DSP_create_wave_tmp0,DSP_create_wave_tmp4

; passage en 2 fois 16 bits
 and    DSP_create_wave_tmp9,DSP_create_wave_tmp3   ; limite aux 16 bits du bas octet 1
 shlq   #16,DSP_create_wave_tmp4                    ; octet 2 en haut
 addq   #8,DSP_create_wave_tmp1
 or     DSP_create_wave_tmp4,DSP_create_wave_tmp3
;--
 subq   #2,DSP_create_wave_tmp8
 store  DSP_create_wave_tmp3,(DSP_create_wave_tmp5)
 addqt  #8,DSP_create_wave_tmp2
 jr     ne,AHX_main_volume_loop
 addqt  #4,DSP_create_wave_tmp5

 movei  #AHX_main_adresse_retour_vers_main_suivant_voie,DSP_create_wave_tmp0
 jump   (DSP_create_wave_tmp0)
 nop

;--------------- subroutine -----------------
; Volume == 0 => fill buffer with zeros
DSP_create_wave_set_volume_zero:
 load   (DSP_create_wave_dest_record_I2S+I2S_index_sample_vc_buffer),DSP_create_wave_volume
 moveq  #0,DSP_create_wave_wavelength
 move   DSP_create_wave_volume,DSP_create_wave_filterpos
 moveq  #0,DSP_create_wave_decaleur_wavelength
 moveq  #16,DSP_create_wave_squarepos
 shlq   #1,DSP_create_wave_squarepos
 addq   #4,DSP_create_wave_filterpos

DSP_create_wave_set_volume_zero_loop:
 store  DSP_create_wave_wavelength,(DSP_create_wave_volume)
 store  DSP_create_wave_decaleur_wavelength,(DSP_create_wave_filterpos)
 subq   #1,DSP_create_wave_squarepos
 addqt  #8,DSP_create_wave_volume
 jr     ne,DSP_create_wave_set_volume_zero_loop
 addqt  #8,DSP_create_wave_filterpos

; fais la boucle sur le channel
 movei  #DSP_create_wave_boucle_recolle1,DSP_create_wave_volume
 jump   (DSP_create_wave_volume)
 nop
;--------------- subroutine -----------------
; Read bits from stream

DSP_AHX_decode_streaming_V4_read_bits_from_bits_streaming:
        jr      non_empty
        moveq   #0,DSP_decode_bits_tmp1
reload:
        load    (DSP_decode_bits_pointeur_lecture_bits),DSP_decode_bits_bitbuffer
        addq    #4,DSP_decode_bits_pointeur_lecture_bits
        moveq   #0,DSP_decode_bits_bitcount
        bset    #5,DSP_decode_bits_bitcount
non_empty:
        move    DSP_decode_bits_bitbuffer,DSP_decode_bits_bits_resultat
        sub     DSP_decode_bits_bits_to_read,DSP_decode_bits_bitcount
        jr      pl,enough_bits
        neg     DSP_decode_bits_bits_to_read

        move    DSP_decode_bits_bits_resultat,DSP_decode_bits_tmp1
        move    DSP_decode_bits_bits_to_read,DSP_decode_bits_bits_resultat
        move    DSP_decode_bits_bitcount,DSP_decode_bits_bits_to_read
        addq    #32,DSP_decode_bits_bits_resultat
        neg     DSP_decode_bits_bits_to_read
        jr      reload
        sh      DSP_decode_bits_bits_resultat,DSP_decode_bits_tmp1

enough_bits:
        sh      DSP_decode_bits_bits_to_read, DSP_decode_bits_bitbuffer
        addq    #32,DSP_decode_bits_bits_to_read
        sh      DSP_decode_bits_bits_to_read,DSP_decode_bits_bits_resultat
        jump    (DSP_decode_bits_adresse_retour)
        or      DSP_decode_bits_tmp1,DSP_decode_bits_bits_resultat
; ---------------------------------------- DSP Datas
         .long
AHX_DSP_Seed_Noise:         dc.l   "AYS!"

AHX_table_routines_a_executer:
 dc.l   AHX_DSP_fill_buffer_triangle
 dc.l   AHX_DSP_fill_buffer_sawtooth
 dc.l   AHX_DSP_fill_buffer_square
 dc.l   AHX_DSP_fill_buffer_noise

DSP_localData:
DSP_module_streaming_bits:      dc.l 0
DSP_module_streaming_bits_cur:  dc.l 0
DSP_module_streaming_bits_end:  dc.l 0
DSP_NB_channels:                dc.l 0
DSP_ratio_Amiga_Jaguar__a_virgule_9_bits:  dc.l    0

;;;
HIVELY_datas_channels:
  .rept  max_NB_channels
 dc.l   0         ; vc_AudioVolume   0
 dc.l   0         ; vc_Waveform     4
 dc.l   0         ; vc_SquarePos    8
 dc.l   0         ; vc_WaveLength    12
 dc.l   0         ; vc_FilterPos    16
 dc.l   0         ; vc_AudioPeriod   20
 dc.l   1         ; channel on ou off ? 24
 dc.l   0         ; vc_RingWaveform
 dc.l   0         ; vc_RingAudioPeriod
  ; Ring Modulation : vc_Waveform+vc_WaveLength+vc_AudioPeriod
  .endr

buffer_temp_wave:  dcb.l  128,0

; NB_channels fois 128 .L , buffers à mixer
buffer_128_1:   dcb.l  64*max_NB_channels,0

DSP_HVL_table_panning_voies_de_base:
index   set    0
 .rept  max_NB_channels
 dc.l   HIVELY_datas_channels+(DSP_index_vc_total*index*4)
index   set  index+1
 .endr

RM_buffers:
        ds.l 128*max_RM_channels

; format de datas pour le replay I2S
i               set 0
rm_buffer       set RM_buffers
rm_buffer_main  set RM_buffers_main
rm_cnt          set 0

I2S_sample_voices:
 .rept  max_NB_channels
 dc.l  0                                ; offset
 dc.l  0                                ; increment
 dc.l  0                                ; mask bouclage
 dc.l  buffer_128_1+(i*64*4)            ; pointeur buffer
 dc.l  255                              ; panning left
 dc.l  255                              ; panning right
 dc.l  0                                ; offset RM
 dc.l  0                                ; increment RM
 dc.l  0

i               set  i+1
 .endr

 print "I2S_sample_voices:",/x/l I2S_sample_voices
 dc.l "ENDE"                    ;-)
;---------------------
; FIN DE LA RAM DSP
code_DSP_end:
;---------------------

SOUND_DRIVER_SIZE   .equ   code_DSP_end-D_RAM+56
 .print "; -----------------------------------------------"
 .print "; --- Sound driver free mem (DSP): ", /u 8192-SOUND_DRIVER_SIZE, " bytes  ---"
 .print "; -----------------------------------------------"
