;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Affichage et déplacement d'un BOB de 32 x 32 pixels en 32 couleurs sur un fond composé de 5 bitplanes en mode RAW Blitter, avec masquage.

;Noter que dans les calculs des adresses pour pointer à l'ordonnée du BOB dans les bitplanes, ce sont des ADD.L Dn,An et non des LEA (An,Dn.W),An qui sont utilisés, car avec 5 bitplanes entrelacés (RAW Blitter), l'offset peut atteindre 320*(256-BOB_DY)*5/8 > 32767...

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DEPTH=5
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+4
	;10*4					Configuration de l'affichage
	;DISPLAY_DEPTH*2*4		Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*4	Palette
	;4						$FFFFFFFE
BOB_X=DISPLAY_DX>>1
BOB_Y=DISPLAY_DY>>1
BOB_DX=64
BOB_DY=64
BOB_DEPTH=DISPLAY_DEPTH
DEBUG=1

;********** Macros **********

WAIT_BLITTER:		MACRO
_waitBlitter0\@
	btst #14,DMACONR(a5)		;Revient à tester le bit 14 % 8 = 6 de l'octet de poids fort de DMACONR, donc BBUSY
	bne _waitBlitter0\@
_waitBlitter1\@
	btst #14,DMACONR(a5)
	bne _waitBlitter1\@
	ENDM	

;********** Initialisations **********

	;Empiler les registres

	movem.l d0-d7/a0-a6,-(sp)
	lea $DFF000,a5

	;Allouer de la mémoire en Chip mise à 0 pour la Copper list

	move.l #COPPERLIST,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,copperList

	;Allouer de la mémoire en Chip mise à 0 pour le fond (background)

	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,background

	;Allouer de la mémoire en Chip mise à 0 pour les bitplanes affichés (front buffer)

	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplanesA
	move.l bitplanesA,frontBuffer

	;Allouer de la mémoire en Chip mise à 0 pour les bitplanes de travail (back buffer)

	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplanesB
	move.l bitplanesB,backBuffer

	;Couper le système

	movea.l $4,a6
	jsr -132(a6)

	;Attendre un VERTB (pour éviter que les sprites ne bavent) et couper les interruptions hardware et les DMA

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
	move.w #0,(a0)+
	move.w #BPLCON2,(a0)+
	move.w #0,(a0)+
	move.w #DDFSTRT,(a0)+
	move.w #((DISPLAY_X-17)>>1)&$00FC,(a0)+
	move.w #DDFSTOP,(a0)+
	move.w #((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC,(a0)+	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	move.w #BPL1MOD,(a0)+
	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),(a0)+			;RAW Blitter pour les bitplanes impairs
	move.w #BPL2MOD,(a0)+
	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),(a0)+			;RAW Blitter pour les bitplanes pairs

	;Comptabilité OCS avec AGA

	move.l #$01FC0000,(a0)+

	;Adresses des bitplanes

	move.w #BPL1PTH,d0
	move.l frontBuffer,d1
	moveq #DISPLAY_DEPTH-1,d2
_bitplanes:
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	addi.l #DISPLAY_DX>>3,d1
	dbf d2,_bitplanes

	;Palette

	lea palette,a1
	move.w #COLOR00,d0
	moveq #(1<<DISPLAY_DEPTH)-1,d1
	IFNE DEBUG				;Rajouter un MOVE inutile n'affectant pas COLOR00 pour ne pas modifier la taille de la Copper list (peut servir)
	addq.w #2,d0
	move.w d0,(a0)+
	move.w (a1)+,(a0)+
	subq.w #1,d1
	ENDIF
_palette:
	move.w d0,(a0)+
	addq.w #2,d0
	move.w (a1)+,(a0)+
	dbf d1,_palette

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

	;Rétablir les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

;********** Programme principal **********

	;Dessiner le fond à base de carrés de 16 x 16 de couleurs successives rebouclant sur la couleur 0

	moveq #0,d0
	movea.l background,a0
	move.w #(DISPLAY_DY>>4)-1,d1
_checkerDrawRows:
	move.w #(DISPLAY_DX>>4)-1,d2
_checkerDrawCols:
	move.b d0,d3
	movea.l a0,a1
	move.w #DISPLAY_DEPTH-1,d4
_checkerDrawBitplanes:
	lsr.b #1,d3
	bcc _checkerSkipBitplane
	movea.l a1,a2
	move.w #16-1,d5
_checkerDrawLines:
	move.w #$FFFF,(a2)
	lea DISPLAY_DEPTH*(DISPLAY_DX>>3)(a2),a2
	dbf d5,_checkerDrawLines
_checkerSkipBitplane:
	lea DISPLAY_DX>>3(a1),a1
	dbf d4,_checkerDrawBitplanes
	lea 2(a0),a0
	addq.b #1,d0
	dbf d2,_checkerDrawCols
	lea (16*DISPLAY_DEPTH-1)*(DISPLAY_DX>>3)(a0),a0
	dbf d1,_checkerDrawRows

	;Recopier le fond dans le front buffer et le back buffer

	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),BLTBMOD(a5)
	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),BLTDMOD(a5)
	move.w #$05CC,BLTCON0(a5)	;USEA=0, USEB=1, USEC=0, USED=1, D=B
	move.w #$0000,BLTCON1(a5)
	move.l background,a0
	move.l frontBuffer,a1
	move.l backBuffer,a2
	move.w #DISPLAY_DEPTH-1,d0
_copyBackground:
	move.l a0,BLTBPTH(a5)
	move.l a1,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER
	move.l a0,BLTBPTH(a5)
	move.l a2,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER
	lea DISPLAY_DX>>3(a0),a0
	lea DISPLAY_DX>>3(a1),a1
	lea DISPLAY_DX>>3(a2),a2
	dbf d0,_copyBackground

	;Boucle principale

_loop:

	;Attendre la fin du tracé de l'écran

	move.w #DISPLAY_Y+DISPLAY_DY,d0
	bsr _waitRaster

	;Deboguage : passer la couleur du fond à rouge au début de la boucle

	IFNE DEBUG
	move.w #$0F00,COLOR00(a5)
	ENDIF

	;Inverser le front et le back buffer

	move.l backBuffer,d0
	move.l frontBuffer,backBuffer
	move.l d0,frontBuffer
	movea.l copperList,a0
	lea 10*4+2(a0),a0
	moveq #DISPLAY_DEPTH-1,d1
_swapBuffers:
	swap d0
	move.w d0,(a0)
	swap d0
	move.w d0,4(a0)
	lea 8(a0),a0
	addi.l #DISPLAY_DX>>3,d0
	dbf d1,_swapBuffers

	;Effacer les lignes du back buffer où se trouvait le bob (recover pas sophistiqué !)

	move.w #0,BLTBMOD(a5)
	move.w #0,BLTDMOD(a5)
	move.w #$05CC,BLTCON0(a5)	;USEA=0, USEB=1, USEC=0, USED=1, D=B
	move.w #$0000,BLTCON1(a5)
	move.l background,a0
	move.w bobY+2,d0
	mulu #DISPLAY_DEPTH*(DISPLAY_DX>>3),d0
	add.l d0,a0
	move.l backBuffer,a1
	add.l d0,a1
	move.l a0,BLTBPTH(a5)
	move.l a1,BLTDPTH(a5)
	move.w #((BOB_DEPTH*BOB_DY)<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Déplacer le BOB en le faisant rebondir sur les bords

	move.w bobX,d0
	move.w d0,bobX+2
	add.w bobSpeedX,d0
	bge _moveBobNoUnderflowX
	neg.w bobSpeedX
	add.w bobSpeedX,d0
	bra _moveBobNoOverflowX
_moveBobNoUnderflowX:
	cmpi.w #DISPLAY_DX-BOB_DX,d0
	blt _moveBobNoOverflowX
	neg.w bobSpeedX
	add.w bobSpeedX,d0
_moveBobNoOverflowX:
	move.w d0,bobX

	move.w bobY,d0
	move.w d0,bobY+2
	add.w bobSpeedY,d0
	bge _moveBobNoUnderflowY
	neg.w bobSpeedY
	add.w bobSpeedY,d0
	bra _moveBobNoOverflowY
_moveBobNoUnderflowY:
	cmpi.w #DISPLAY_DY-BOB_DY,d0
	blt _moveBobNoOverflowY
	neg.w bobSpeedY
	add.w bobSpeedY,d0
_moveBobNoOverflowY:
	move.w d0,bobY

	;Dessiner le BOB

	moveq #0,d1
	move.w bobX,d0
	move.w d0,d1
	and.w #$F,d0
	ror.w #4,d0
	move.w d0,BLTCON1(a5)		;BSH3-0=décalage
	or.w #$0FF2,d0
	move.w d0,BLTCON0(a5)		;ASH3-0=décalage, USEA=1, USEB=0, USEC=1, USED=1, D=A+bC
	lsr.w #3,d1
	and.b #$FE,d1
	move.w bobY,d0
	mulu #DISPLAY_DEPTH*(DISPLAY_DX>>3),d0
	add.l d1,d0

	movea.l backBuffer,a0
	add.l d0,a0
	move.w #$FFFF,BLTAFWM(a5)
	move.w #$0000,BLTALWM(a5)
	move.w #-2,BLTAMOD(a5)
	move.w #0,BLTBMOD(a5)
	move.w #(DISPLAY_DX-(BOB_DX+16))>>3,BLTCMOD(a5)
	move.w #(DISPLAY_DX-(BOB_DX+16))>>3,BLTDMOD(a5)
	move.l #bob,BLTAPTH(a5)
	move.l #mask,BLTBPTH(a5)
	move.l a0,BLTCPTH(a5)
	move.l a0,BLTDPTH(a5)
	move.w #(BOB_DEPTH*(BOB_DY<<6))!((BOB_DX+16)>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Deboguage : passer la couleur du fond à vert à la fin de la boucle

	IFNE DEBUG
	move.w #$00F0,COLOR00(a5)
	ENDIF

	;Tester une pression du bouton gauche de la souris

	btst #6,$BFE001
	bne _loop

;********** Finalisations **********

	;Attendre un VERTB (pour éviter que les sprites ne bavent) et couper les interruptions hardware et les DMA

	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	bsr _waitVERTB
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

	;Rétablir le système

	movea.l $4,a6
	jsr -138(a6)

	;Libérer la mémoire

	movea.l background,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l bitplanesA,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l bitplanesB,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	movea.l $4,a6
	jsr -210(a6)

	;Dépiler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Routines **********

	INCLUDE "SOURCES:spritesAndBobs/registers.s"

;---------- Gestionnaire d'interruption ----------

_rte:
	rte

;---------- Attente du blanc vertical (ne fonctionne que si l'interruption VERTB est activée !) ----------

_waitVERTB:
	movem.w d0,-(sp)
_waitVERTBLoop:
	move.w INTREQR(a5),d0
	btst #5,d0
	beq _waitVERTBLoop
	movem.w (sp)+,d0
	rts

;---------- Attente du raster à une ligne ----------

;Entrée(s) :
;	D0 = Ligne où le raster est attendu
;Sortie(s) :
;	(aucune)
;Notice :
;	Attention si la boucle d'où provient l'appel prend moins d'une ligne pour s'exécuter, car il faut alors deux appels :
;
;	move.w #Y+1,d0
;	bsr _waitRaster
;	move.w #Y,d0
;	bsr _waitRaster

_waitRaster:
	movem.l d1,-(sp)
_waitRasterLoop:
	move.l VPOSR(a5),d1
	lsr.l #8,d1
	and.w #$01FF,d1
	cmp.w d0,d1
	bne _waitRasterLoop
	movem.l (sp)+,d1
	rts

;********** Données **********

graphicsLibrary:	DC.B "graphics.library",0
					EVEN
dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
vectors:			BLK.L 6
copperList:			DC.L 0
background:			DC.L 0
bitplanesA:			DC.L 0
bitplanesB:			DC.L 0
backBuffer:			DC.L 0
frontBuffer:		DC.L 0
palette:
					DC.W $0000
					DC.W $0FFF
					DC.W $0700
					DC.W $0900
					DC.W $0B00
					DC.W $0D00
					DC.W $0F00
					DC.W $0070
					DC.W $0090
					DC.W $00B0
					DC.W $00D0
					DC.W $00F0
					DC.W $0007
					DC.W $0009
					DC.W $000B
					DC.W $000D
					DC.W $000F
					DC.W $0770
					DC.W $0990
					DC.W $0BB0
					DC.W $0DD0
					DC.W $0FF0
					DC.W $0707
					DC.W $0909
					DC.W $0B0B
					DC.W $0D0D
					DC.W $0F0F
					DC.W $0077
					DC.W $0099
					DC.W $00BB
					DC.W $00DD
					DC.W $00FF
bobX:				DC.W BOB_X, 0
bobY:				DC.W BOB_Y, 0
bobSpeedX:			DC.W 2
bobSpeedY:			DC.W 3
bob:
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0000, $0000, $0000, $0000
					DC.W $F000, $F000, $F000, $F000
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $0000, $0000, $0000, $00F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $0000, $0000, $0000, $00F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $0000, $0000, $0000, $00F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $0000, $0000, $0000, $00F0
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $000F, $0F00, $000F, $0F00
					DC.W $0000, $000F, $0F0F, $0F00
					DC.W $0000, $0000, $0000, $000F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $F000, $F000, $F000, $F0F0
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F000, $F000, $F000, $F0F0
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F000, $F000, $F000, $F0F0
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F000, $F000, $F000, $F0F0
					DC.W $00F0, $F000, $00F0, $F000
					DC.W $0000, $00F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $F0F0, $F0F0, $F0F0, $F000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $F0F0, $0000, $F0F0, $0000
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $0000, $0000, $0000, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $F0F0, $0000, $F0F0, $0000
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $0000, $0000, $0000, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $F0F0, $0000, $F0F0, $0000
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $0000, $0000, $0000, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $F0F0, $0000, $F0F0, $0000
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $0000, $0000, $0000, $F0F0
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0F0F, $0000, $0F0F, $0000
					DC.W $0000, $0F0F, $0F0F, $0000
					DC.W $0000, $0000, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $00F0, $00F0, $00F0, $F000
					DC.W $F0F0, $0000, $F0F0, $00F0
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $00F0, $00F0, $00F0, $F000
					DC.W $F0F0, $0000, $F0F0, $00F0
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $00F0, $00F0, $00F0, $F000
					DC.W $F0F0, $0000, $F0F0, $00F0
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $00F0, $00F0, $00F0, $F000
					DC.W $F0F0, $0000, $F0F0, $00F0
					DC.W $0000, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $F000, $F000, $F000, $F000
					DC.W $F000, $00F0, $F000, $00F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $0000, $0000, $00F0, $F0F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $F000, $00F0, $F000, $00F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $0000, $0000, $00F0, $F0F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $F000, $00F0, $F000, $00F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $0000, $0000, $00F0, $F0F0
					DC.W $F000, $F000, $F000, $F000
					DC.W $F000, $00F0, $F000, $00F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $0000, $0000, $00F0, $F0F0
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $0F00, $0F00, $0F00, $0F00
					DC.W $0F00, $000F, $0F00, $000F
					DC.W $000F, $0F0F, $0F00, $0000
					DC.W $0000, $0000, $000F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $F000, $F000, $F0F0, $00F0
					DC.W $F000, $00F0, $F000, $F0F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F000, $F000, $F0F0, $00F0
					DC.W $F000, $00F0, $F000, $F0F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F000, $F000, $F0F0, $00F0
					DC.W $F000, $00F0, $F000, $F0F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F000, $F000, $F0F0, $00F0
					DC.W $F000, $00F0, $F000, $F0F0
					DC.W $00F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $F0F0, $F0F0, $F000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0000, $0000, $0000, $0000
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $0000, $F0F0, $0000, $F0F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $0000, $0000, $F0F0, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $0000, $F0F0, $0000, $F0F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $0000, $0000, $F0F0, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $0000, $F0F0, $0000, $F0F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $0000, $0000, $F0F0, $F0F0
					DC.W $00F0, $00F0, $00F0, $00F0
					DC.W $0000, $F0F0, $0000, $F0F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $0000, $0000, $F0F0, $F0F0
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $000F, $000F, $000F, $000F
					DC.W $0000, $0F0F, $0000, $0F0F
					DC.W $0F0F, $0F0F, $0000, $0000
					DC.W $0000, $0000, $0F0F, $0F0F
					DC.W $0F0F, $0F0F, $0F0F, $0F0F
					DC.W $00F0, $00F0, $F000, $F000
					DC.W $0000, $F0F0, $00F0, $F000
					DC.W $F0F0, $F0F0, $0000, $00F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $00F0, $00F0, $F000, $F000
					DC.W $0000, $F0F0, $00F0, $F000
					DC.W $F0F0, $F0F0, $0000, $00F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $00F0, $00F0, $F000, $F000
					DC.W $0000, $F0F0, $00F0, $F000
					DC.W $F0F0, $F0F0, $0000, $00F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $00F0, $00F0, $F000, $F000
					DC.W $0000, $F0F0, $00F0, $F000
					DC.W $F0F0, $F0F0, $0000, $00F0
					DC.W $F0F0, $F0F0, $0000, $0000
					DC.W $F0F0, $F0F0, $0000, $0000
mask:
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR
					REPT 4
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					DC.W $0F0F, $0F0F, $0F0F, $0F0F, $0000
					ENDR
					REPT 4
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					DC.W $F0F0, $F0F0, $F0F0, $F0F0, $0000
					ENDR

