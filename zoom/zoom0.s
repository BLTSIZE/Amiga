;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr, stashofcode@gmail.com) en 2018.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Exemple de dissimulation des lignes par modification de DIWSTRT, DIWSTOP, BPLxPTH/L et BPLxMOD. Il s'agit simplement de réduire l'image (PICTURE_DX x PICTURE_DY pixels) en dissimulant les ZOOM_N premières lignes, les ZOOM_N lignes médianes et les ZOOM_N dernières lignes, et de centrer verticalement le résultat à l'écran. L'image est affichée normalement, et ainsi zoomée lorsque le bouton gauche de la souris et pressé puis relâché. Pour ce faire, les valeurs écrites par des MOVE dans la Copper list sont modifiées.

;********** Constantes **********

;Programme

DISPLAY_DEPTH=5
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
PICTURE_DX=DISPLAY_DX		;Constante introduite pour clarifier en distinguant ce qui concerne l'écran (DISPLAY_*) de ce qui concerne l'image (PICTURE_*)
PICTURE_DY=DISPLAY_DY		;Idem
ZOOM_N=16
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+2*(1+1+1)*4+4
	;10*4					Configuration de l'affichage
	;DISPLAY_DEPTH*2*4		Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*4	Palette
	;2*(1+1+1)*4			2 fois la séquence : WAIT, MOVE sur BPL1MOD et MOVE sur BPL2MOD
	;4						$FFFFFFFE
DEBUG=0

;********** Macros **********

;Attendre le Blitter. Quand la seconde opérande est une adresse, BTST ne permet de tester que les bits 7-0 de l'octet pointé, mais traitant la première opérande comme le numéro du bit modulo 8, BTST #14,DMACONR(a5) revient à tester le bit 14%8=6 de l'octet de poids fort de DMACONR, ce qui correspond bien à BBUSY...

WAIT_BLITTER:	MACRO
_WAIT_BLITTER0\@
	btst #14,DMACONR(a5)
	bne _WAIT_BLITTER0\@
_WAIT_BLITTER1\@
	btst #14,DMACONR(a5)
	bne _WAIT_BLITTER1\@
	ENDM

;********** Initialisations **********

	SECTION code,CODE

	;Empiler les registres

	movem.l d0-d7/a0-a6,-(sp)

	;StingRay's stuff

	lea graphicsLibrary,a1
	movea.l $4,a6
	jsr -408(a6)		;OpenLibrary ()
	move.l d0,graphicsBase
	move.l graphicsBase,a6
	move.l $22(a6),view
	movea.l #0,a1
	jsr -222(a6)		;LoadView ()
	jsr -270(a6)		;WaitTOF ()
	jsr -270(a6)		;WaitTOF ()
	jsr -228(a6)		;WaitBlit ()
	jsr -456(a6)		;OwnBlitter ()
	move.l graphicsBase,a1
	movea.l $4,a6
	jsr -414(a6)		;CloseLibrary ()

	;Couper le système

	jsr -132(a6)		;Forbid ()

	;Allouer de la mémoire en Chip mise à 0 pour la Copper list

	move.l #COPPERLIST,d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,copperList

	;Attendre un VERTB (pour éviter que les sprites ne bavent) et couper les interruptions hardware et les DMA

	lea $DFF000,a5
	bsr _waitVERTB
	move.w INTENAR(a5),intena
	move.w #$7FFF,INTENA(a5)
	move.w INTREQR(a5),intreq
	move.w #$7FFF,INTREQ(a5)
	move.w DMACONR(a5),dmacon
	move.w #$07FF,DMACON(a5)

	;Détourner les vecteurs d'interruption hardware (niveau 1 à 6 correspondant aux vecteurs 25 à 30 pointant sur les adresses $64 à $78)

	lea $64,a0
	lea vectors,a1
	REPT 6
	move.l (a0),(a1)+
	move.l #_rte,(a0)+
	ENDR

;********** Copper list **********

	movea.l copperList,a0

	;Configuration de l'écran

	move.w #DIWSTRT,(a0)+
	move.w #(DISPLAY_Y<<8)!DISPLAY_X,(a0)+
	move.w #DIWSTOP,(a0)+
	move.w #((DISPLAY_Y+DISPLAY_DY-256)<<8)!(DISPLAY_X+DISPLAY_DX-256),(a0)+
	move.w #BPLCON0,(a0)+
	move.w #(DISPLAY_DEPTH<<12)!$0200,(a0)+
	move.w #BPLCON1,(a0)+
	move.w #$0000,(a0)+
	move.w #BPLCON2,(a0)+
	move.w #$0000,(a0)+
	move.w #DDFSTRT,(a0)+
	move.w #((DISPLAY_X-17)>>1)&$00FC,(a0)+
	move.w #DDFSTOP,(a0)+
	move.w #((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC,(a0)+	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+
	move.w #FMODE,(a0)+
	move.w #0,(a0)+

	;Adresses des bitplanes

	move.l #picture,d0
	move.w #BPL1PTH,d1
	moveq #DISPLAY_DEPTH-1,d2
_bitplanes:
	move.w d1,(a0)+
	addq.w #2,d1
	swap d0
	move.w d0,(a0)+
	move.w d1,(a0)+
	addq.w #2,d1
	swap d0
	move.w d0,(a0)+
	addi.l #PICTURE_DY*(PICTURE_DX>>3),d0
	dbf d2,_bitplanes

	;Palette

	lea picture,a1
	addi.l #DISPLAY_DEPTH*PICTURE_DY*(PICTURE_DX>>3),a1
	moveq #1,d0
	lsl.b #DISPLAY_DEPTH,d0
	subq.b #1,d0
	move.w #COLOR00,d1
_colors:
	move.w d1,(a0)+
	addq.w #2,d1
	move.w (a1)+,(a0)+
	dbf d0,_colors

	;Dissimulation des ZOOM_N lignes médianes (pour l'heure, neutralisée)

	move.w #((DISPLAY_Y+((3*ZOOM_N)>>1)+((PICTURE_DY-ZOOM_N)>>1)-ZOOM_N-1)<<8)!$0001,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+

	;Après cette ligne, et avant la fin de la suivante, BPLxMOD doit être repassé à sa valeur initiale

	move.w #((DISPLAY_Y+((3*ZOOM_N)>>1)+((PICTURE_DY-ZOOM_N)>>1)-ZOOM_N)<<8)!$0001,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Rétablir les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

	;Attendre un clique de la souris

_waitLButtonPushed:
	btst #6,$BFE001
	bne _waitLButtonPushed
_waitLButtonReleased
	btst #6,$BFE001
	beq _waitLButtonReleased

	;Modifier l'adresse de départ des bitplanes pour dissimuler les ZOOM_N premières lignes

	movea.l copperList,a0
	lea 10*4(a0),a0
	move.l #picture+ZOOM_N*(PICTURE_DX>>3),d0
	moveq #DISPLAY_DEPTH-1,d1
_updateBitplanes:
	swap d0
	move.w d0,2(a0)
	lea 4(a0),a0
	swap d0
	move.w d0,2(a0)
	lea 4(a0),a0
	addi.l #PICTURE_DY*(PICTURE_DX>>3),d0
	dbf d1,_updateBitplanes

	;Modifier les valeurs affectées à BPLxMOD au milieu de l'écran pour dissimuler les ZOOM_N lignes médianes

	movea.l copperList,a0
	lea 10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+4(a0),a0
	move.w #ZOOM_N*(PICTURE_DX>>3),2(a0)
	move.w #ZOOM_N*(PICTURE_DX>>3),4+2(a0)

	;Modifier DIWSTRT et DIWSTOP pour centrer l'image et dissimuler les ZOOM_N dernières lignes

	movea.l copperList,a0
	move.w #((DISPLAY_Y+((3*ZOOM_N)>>1))<<8)!DISPLAY_X,2(a0)
	move.w #((DISPLAY_Y+DISPLAY_DY-((3*ZOOM_N)>>1)-256)<<8)!(DISPLAY_X+DISPLAY_DX-256),4+2(a0)

	;Boucle principale

_loop:
	btst #6,$BFE001
	bne _loop

;********** Finalisations **********

	;Couper les interruptions hardware et les DMA

	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	move.w #$07FF,DMACON(a5)

	;Rétablir les vecteurs	d'interruption

	lea $64,a0
	lea vectors,a1
	REPT 6
	move.l (a1)+,(a0)+
	ENDR

	;Rétablir les interruptions hardware et les DMA

	move.w dmacon,d0
	bset #15,d0
	move.w d0,DMACON(a5)
	move.w intreq,d0
	bset #15,d0
	move.w d0,INTREQ(a5)
	move.w intena,d0
	bset #15,d0
	move.w d0,INTENA(a5)

	;Rétablir la Copper list

	lea graphicsLibrary,a1
	movea.l $4,a6
	jsr -408(a6)
	move.l d0,a1
	move.l 38(a1),COP1LCH(a5)
	clr.w COPJMP1(a5)
	jsr -414(a6)

	;StingRay's stuff

	movea.l view,a1
	move.l graphicsBase,a6
	jsr -222(a6)		;LoadView ()
	jsr -462(a6)		;DisownBlitter ()
	move.l graphicsBase,a1
	movea.l $4,a6
	jsr -414(a6)		;CloseLibrary ()

	;Rétablir le système

	jsr -138(a6)

	;Libérer la mémoire

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	jsr -210(a6)

	;Dépiler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Routines **********

	INCLUDE "common/registers.s"
	INCLUDE "common/wait.s"

;---------- Gestionnaire d'interruption ----------

_rte:
	rte

;********** Données **********

	SECTION data,DATA_C

graphicsLibrary:	DC.B "graphics.library",0
					EVEN
view:				DC.L 0
graphicsBase:		DC.L 0
vectors:			BLK.L 6
copperList:			DC.L 0
bitplanes:			DC.L 0
dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
picture:			INCBIN "SOURCES:zoom/dragonSun320x256x5.raw"
