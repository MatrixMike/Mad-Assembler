
	org $80

product	.ds 4
t1	.ds 2
t2	.ds 2

	org $a000

square1_lo	.ds $200
square1_hi	.ds $200
square2_lo	.ds $200
square2_hi	.ds $200

	org $2000

main
	jsr init

	mwa #12356 t1
	mwa #32784 t2
	jsr fmulu

	jmp *


.proc	fmulu

; Description: Unsigned 16-bit multiplication with unsigned 32-bit result.
;
; Input: 16-bit unsigned value in T1
;	 16-bit unsigned value in T2
;	 Carry=0: Re-use T1 from previous multiplication (faster)
;	 Carry=1: Set T1 (slower)
;
; Output: 32-bit unsigned value in PRODUCT
;
; Clobbered: PRODUCT, X, A, C
;
; Allocation setup: T1,T2 and PRODUCT preferably on Zero-page.
;		    square1_lo, square1_hi, square2_lo, square2_hi must be
;		    page aligned. Each table are 512 bytes. Total 2kb.
;
; Table generation: I:0..511
;		    square1_lo = <((I*I)/4)
;		    square1_hi = >((I*I)/4)
;		    square2_lo = <(((I-255)*(I-255))/4)
;		    square2_hi = >(((I-255)*(I-255))/4)
//.proc multiply_16bit_unsigned
		; <T1 * <T2 = AAaa
		; <T1 * >T2 = BBbb
		; >T1 * <T2 = CCcc
		; >T1 * >T2 = DDdd
		;
		;	AAaa
		;     BBbb
		;     CCcc
		; + DDdd
		; ----------
		;   PRODUCT!

		; Setup T1 if changed
;		bcc @+
		    lda T1+0
		    sta sm1a+1
		    sta sm3a+1
		    sta sm5a+1
		    sta sm7a+1
		    eor #$ff
		    sta sm2a+1
		    sta sm4a+1
		    sta sm6a+1
		    sta sm8a+1
		    lda T1+1
		    sta sm1b+1
		    sta sm3b+1
		    sta sm5b+1
		    sta sm7b+1
		    eor #$ff
		    sta sm2b+1
		    sta sm4b+1
		    sta sm6b+1
		    sta sm8b+1
@
		; Perform <T1 * <T2 = AAaa
		ldx T2+0
		sec
sm1a:		lda square1_lo,x
sm2a:		sbc square2_lo,x
		sta PRODUCT+0
sm3a:		lda square1_hi,x
sm4a:		sbc square2_hi,x
		sta _AA+1

		; Perform >T1_hi * <T2 = CCcc
		sec
sm1b:		lda square1_lo,x
sm2b:		sbc square2_lo,x
		sta _cc+1
sm3b:		lda square1_hi,x
sm4b:		sbc square2_hi,x
		sta _CC_+1

		; Perform <T1 * >T2 = BBbb
		ldx T2+1
		sec
sm5a:		lda square1_lo,x
sm6a:		sbc square2_lo,x
		sta _bb+1
sm7a:		lda square1_hi,x
sm8a:		sbc square2_hi,x
		sta _BB_+1

		; Perform >T1 * >T2 = DDdd
		sec
sm5b:		lda square1_lo,x
sm6b:		sbc square2_lo,x
		sta _dd+1
sm7b:		lda square1_hi,x
sm8b:		sbc square2_hi,x
		sta PRODUCT+3

		; Add the separate multiplications together
		clc
_AA:		lda #0
_bb:		adc #0
		sta PRODUCT+1
_BB_:		lda #0
_CC_:		adc #0
		sta PRODUCT+2
		bcc @+
		    inc PRODUCT+3
		    clc
@
_cc:		lda #0
		adc PRODUCT+1
		sta PRODUCT+1
_dd:		lda #0
		adc PRODUCT+2
		sta PRODUCT+2
		scc
		    inc PRODUCT+3

		rts
.endp


; Description: Signed 16-bit multiplication with signed 32-bit result.
;
; Input: 16-bit signed value in T1
;	 16-bit signed value in T2
;	 Carry=0: Re-use T1 from previous multiplication (faster)
;	 Carry=1: Set T1 (slower)
;
; Output: 32-bit signed value in PRODUCT
;
; Clobbered: PRODUCT, X, A, C

.proc fmuls
		jsr fmulu

		; Apply sign (See C=Hacking16 for details).
		lda T1+1
		bpl @+
		    sec
		    lda PRODUCT+2
		    sbc T2+0
		    sta PRODUCT+2
		    lda PRODUCT+3
		    sbc T2+1
		    sta PRODUCT+3
@
		lda T2+1
		bpl @+
		    sec
		    lda PRODUCT+2
		    sbc T1+0
		    sta PRODUCT+2
		    lda PRODUCT+3
		    sbc T1+1
		    sta PRODUCT+3
@
		rts
.endp


.proc	init

	ldx #$00
	txa
	.byte $c9	; CMP #immediate - skip TYA and clear carry flag
lb1:	tya
	adc #$00
ml1:	sta square1_hi,x
	tay
	cmp #$40
	txa
	ror @
ml9:	adc #$00
	sta ml9+1
	inx
ml0:	sta square1_lo,x
	bne lb1
	inc ml0+2
	inc ml1+2
	clc
	iny
	bne lb1

	ldx #$00
	ldy #$ff
lp	lda square1_hi+1,x
	sta square2_hi+$100,x
	lda square1_hi,x
	sta square2_hi,y
	lda square1_lo+1,x
	sta square2_lo+$100,x
	lda square1_lo,x
	sta square2_lo,y
	dey
	inx
	bne lp

	rts

.endp

	run main