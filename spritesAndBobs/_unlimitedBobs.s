;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;"Unlimited bobs" avec un BOB de 16 x 16 pixels en 4 couleurs. Version avec une courbe paramétrique dont les rayons évoluent linéairement dans des intervalles, en plus des angles, qui n'apporte rien de plus.

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DEPTH=2
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+4
	;10*4					Configuration de l'affichage
	;DISPLAY_DEPTH*2*4		Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*4	Palette
	;4						$FFFFFFFE
BOB_DX=16
BOB_DY=16
BOB_DEPTH=DISPLAY_DEPTH
NBFRAMES=8
RADIUSX_MIN=10
RADIUSX_MAX=(DISPLAY_DX-BOB_DX)>>1
RADIUSX_SPEED=1
RADIUSY_MIN=20
RADIUSY_MAX=(DISPLAY_DY-BOB_DY)>>1
RADIUSY_SPEED=2
ANGLEX_SPEED=2
ANGLEY_SPEED=1

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

	;Allouer de la mémoire en Chip mise à 0 pour les images de l'animation (une par une pour rester sous la taille maximale d'un bloc disponible)

	movea.l $4,a6
	lea images,a0
	moveq #NBFRAMES-1,d2
_allocImages:
	move.l #$10002,d1
	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	movem.l a0/d2,-(sp)
	jsr -198(a6)
	movem.l (sp)+,a0/d2
	move.l d0,(a0)+
	dbf d2,_allocImages

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
	move.l images,d1
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

	lea bob+BOB_DEPTH*BOB_DY*(BOB_DX>>3),a1
	move.w #COLOR00,d0
	moveq #(1<<DISPLAY_DEPTH)-1,d1
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

	;Créer le masque du bob

	lea bob,a0
	lea bobMask,a1
	moveq #BOB_DY-1,d0
_maskRows:
	moveq #(BOB_DX>>4)-1,d1

_maskCols:
	movea.l a0,a2
	moveq #0,d3
	moveq #BOB_DEPTH-1,d2

_maskGetWord:
	or.w (a2),d3
	lea BOB_DX>>3(a2),a2
	dbf d2,_maskGetWord

	movea.l a1,a2
	moveq #BOB_DEPTH-1,d2
_maskSetWord:
	move.w d3,(a2)
	lea (BOB_DX+16)>>3(a2),a2
	dbf d2,_maskSetWord
	
	lea 2(a0),a0
	lea 2(a1),a1
	dbf d1,_maskCols

	lea ((BOB_DEPTH-1)*BOB_DX)>>3(a0),a0
	lea 2+(((BOB_DEPTH-1)*(BOB_DX+16))>>3)(a1),a1
	dbf d0,_maskRows
	
	;Positionner le bob à position initiale

	move.w #0,bobX
	move.w #0,bobY
	move.w #RADIUSX_MIN,radiusX
	move.w #RADIUSX_SPEED,radiusXSpeed
	move.w #RADIUSY_MIN,radiusY
	move.w #RADIUSY_SPEED,radiusYSpeed
	
	;Boucle principale

_loop:

	;Attendre la fin du tracé de l'écran

	move.w #DISPLAY_Y+DISPLAY_DY,d0
	bsr _waitRaster

	;Permuter circulairement les images (la seconde devient la première, ..., la première devient la dernière)

	lea images,a0
	move.l (a0),d1
	lea 4(a0),a1
	moveq #NBFRAMES-2,d0
_swapImages:
	move.l (a1)+,(a0)+
	dbf d0,_swapImages
	move.l d1,(a0)

	;Changer l'image affichée

	move.l images,d0
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

	;Animer la position

	move.w angleX,d0
	subi.w #ANGLEX_SPEED<<1,d0
	bge _noAngleXUnderflow
	addi.w #360<<1,d0
_noAngleXUnderflow:
	move.w d0,angleX

	move.w angleY,d1
	subi.w #ANGLEY_SPEED<<1,d1
	bge _noAngleYUnderflow
	addi.w #360<<1,d1
_noAngleYUnderflow:
	move.w d1,angleY

	move.w radiusX,d2
	add.w radiusXSpeed,d2
	bge _noRadiusXUnderflow
	neg.w radiusXSpeed
	add.w radiusXSpeed,d2
	bra _noRadiusXOverflow
_noRadiusXUnderflow:
	cmpi.w #RADIUSX_MAX,d2
	ble _noRadiusXOverflow
	neg.w radiusXSpeed
	add.w radiusXSpeed,d2
_noRadiusXOverflow:
	move.w d2,radiusX
	
	move.w radiusY,d3
	add.w radiusYSpeed,d3
	bge _noRadiusYUnderflow
	neg.w radiusYSpeed
	add.w radiusYSpeed,d3
	bra _noRadiusYOverflow
_noRadiusYUnderflow:
	cmpi.w #RADIUSY_MAX,d3
	ble _noRadiusYOverflow
	neg.w radiusYSpeed
	add.w radiusYSpeed,d3
_noRadiusYOverflow:
	move.w d3,radiusY

	;Calculer la position suivante du bob

	lea cosinus,a0
	move.w (a0,d0.w),d4
	muls d2,d4
	swap d4
	rol.l #2,d4
	addi.w #DISPLAY_DX>>1,d4
	move.w d4,bobX
	
	lea sinus,a0
	move.w (a0,d1.w),d4
	muls d3,d4
	swap d4
	rol.l #2,d4
	addi.w #DISPLAY_DY>>1,d4
	move.w d4,bobY

	;Dessiner le bob à la position suivante dans l'image suivante

	moveq #0,d1
	move.w bobX,d0
	subi.w #BOB_DX>>1,d0
	move.w d0,d1
	and.w #$F,d0
	ror.w #4,d0
	move.w d0,BLTCON1(a5)		;BSH3-0=décalage
	or.w #$0FF2,d0				;ASH3-0=décalage, USEA=1, USEB=1, USEC=1, USED=1, D=A+bC
	move.w d0,BLTCON0(a5)
	lsr.w #3,d1
	and.b #$FE,d1
	move.w bobY,d0
	subi.w #BOB_DY>>1,d0
	mulu #DISPLAY_DEPTH*(DISPLAY_DX>>3),d0
	add.l d1,d0
	move.l images+4,d1
	add.l d1,d0
	move.w #$FFFF,BLTAFWM(a5)
	move.w #$0000,BLTALWM(a5)
	move.w #-2,BLTAMOD(a5)
	move.w #0,BLTBMOD(a5)
	move.w #(DISPLAY_DX-(BOB_DX+16))>>3,BLTCMOD(a5)
	move.w #(DISPLAY_DX-(BOB_DX+16))>>3,BLTDMOD(a5)
	move.l #bob,BLTAPTH(a5)
	move.l #bobMask,BLTBPTH(a5)
	move.l d0,BLTCPTH(a5)
	move.l d0,BLTDPTH(a5)
	move.w #(BOB_DEPTH*(BOB_DY<<6))!((BOB_DX+16)>>4),BLTSIZE(a5)
	WAIT_BLITTER

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

	movea.l $4,a6
	lea images,a0
	moveq #NBFRAMES-1,d1
_freeImages:
	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	movea.l (a0)+,a1
	movem.l a0/d1,-(sp)
	jsr -210(a6)
	movem.l (sp)+,a0/d1
	dbf d1,_freeImages

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
bobX:				DC.W 0
bobY:				DC.W 0
angleX:				DC.W 0
angleY:				DC.W 0
radiusX:			DC.W 0
radiusXSpeed:		DC.W 0
radiusY:			DC.W 0
radiusYSpeed:		DC.W 0
bobMask:
					BLK.W BOB_DEPTH*BOB_DY*((BOB_DX+16)>>4),0
bob:
					INCBIN "SOURCES:spritesAndBobs/ballBlue16x16x2.rawb"
images:				BLK.L NBFRAMES,0
sinus:				DC.W 0, 286, 572, 857, 1143, 1428, 1713, 1997, 2280, 2563, 2845, 3126, 3406, 3686, 3964, 4240, 4516, 4790, 5063, 5334, 5604, 5872, 6138, 6402, 6664, 6924, 7182, 7438, 7692, 7943, 8192, 8438, 8682, 8923, 9162, 9397, 9630, 9860, 10087, 10311, 10531, 10749, 10963, 11174, 11381, 11585, 11786, 11982, 12176, 12365, 12551, 12733, 12911, 13085, 13255, 13421, 13583, 13741, 13894, 14044, 14189, 14330, 14466, 14598, 14726, 14849, 14968, 15082, 15191, 15296, 15396, 15491, 15582, 15668, 15749, 15826, 15897, 15964, 16026, 16083, 16135, 16182, 16225, 16262, 16294, 16322, 16344, 16362, 16374, 16382, 16384, 16382, 16374, 16362, 16344, 16322, 16294, 16262, 16225, 16182, 16135, 16083, 16026, 15964, 15897, 15826, 15749, 15668, 15582, 15491, 15396, 15296, 15191, 15082, 14968, 14849, 14726, 14598, 14466, 14330, 14189, 14044, 13894, 13741, 13583, 13421, 13255, 13085, 12911, 12733, 12551, 12365, 12176, 11982, 11786, 11585, 11381, 11174, 10963, 10749, 10531, 10311, 10087, 9860, 9630, 9397, 9162, 8923, 8682, 8438, 8192, 7943, 7692, 7438, 7182, 6924, 6664, 6402, 6138, 5872, 5604, 5334, 5063, 4790, 4516, 4240, 3964, 3686, 3406, 3126, 2845, 2563, 2280, 1997, 1713, 1428, 1143, 857, 572, 286, 0, -286, -572, -857, -1143, -1428, -1713, -1997, -2280, -2563, -2845, -3126, -3406, -3686, -3964, -4240, -4516, -4790, -5063, -5334, -5604, -5872, -6138, -6402, -6664, -6924, -7182, -7438, -7692, -7943, -8192, -8438, -8682, -8923, -9162, -9397, -9630, -9860, -10087, -10311, -10531, -10749, -10963, -11174, -11381, -11585, -11786, -11982, -12176, -12365, -12551, -12733, -12911, -13085, -13255, -13421, -13583, -13741, -13894, -14044, -14189, -14330, -14466, -14598, -14726, -14849, -14968, -15082, -15191, -15296, -15396, -15491, -15582, -15668, -15749, -15826, -15897, -15964, -16026, -16083, -16135, -16182, -16225, -16262, -16294, -16322, -16344, -16362, -16374, -16382, -16384, -16382, -16374, -16362, -16344, -16322, -16294, -16262, -16225, -16182, -16135, -16083, -16026, -15964, -15897, -15826, -15749, -15668, -15582, -15491, -15396, -15296, -15191, -15082, -14968, -14849, -14726, -14598, -14466, -14330, -14189, -14044, -13894, -13741, -13583, -13421, -13255, -13085, -12911, -12733, -12551, -12365, -12176, -11982, -11786, -11585, -11381, -11174, -10963, -10749, -10531, -10311, -10087, -9860, -9630, -9397, -9162, -8923, -8682, -8438, -8192, -7943, -7692, -7438, -7182, -6924, -6664, -6402, -6138, -5872, -5604, -5334, -5063, -4790, -4516, -4240, -3964, -3686, -3406, -3126, -2845, -2563, -2280, -1997, -1713, -1428, -1143, -857, -572, -286
cosinus:			DC.W 16384, 16382, 16374, 16362, 16344, 16322, 16294, 16262, 16225, 16182, 16135, 16083, 16026, 15964, 15897, 15826, 15749, 15668, 15582, 15491, 15396, 15296, 15191, 15082, 14968, 14849, 14726, 14598, 14466, 14330, 14189, 14044, 13894, 13741, 13583, 13421, 13255, 13085, 12911, 12733, 12551, 12365, 12176, 11982, 11786, 11585, 11381, 11174, 10963, 10749, 10531, 10311, 10087, 9860, 9630, 9397, 9162, 8923, 8682, 8438, 8192, 7943, 7692, 7438, 7182, 6924, 6664, 6402, 6138, 5872, 5604, 5334, 5063, 4790, 4516, 4240, 3964, 3686, 3406, 3126, 2845, 2563, 2280, 1997, 1713, 1428, 1143, 857, 572, 286, 0, -286, -572, -857, -1143, -1428, -1713, -1997, -2280, -2563, -2845, -3126, -3406, -3686, -3964, -4240, -4516, -4790, -5063, -5334, -5604, -5872, -6138, -6402, -6664, -6924, -7182, -7438, -7692, -7943, -8192, -8438, -8682, -8923, -9162, -9397, -9630, -9860, -10087, -10311, -10531, -10749, -10963, -11174, -11381, -11585, -11786, -11982, -12176, -12365, -12551, -12733, -12911, -13085, -13255, -13421, -13583, -13741, -13894, -14044, -14189, -14330, -14466, -14598, -14726, -14849, -14968, -15082, -15191, -15296, -15396, -15491, -15582, -15668, -15749, -15826, -15897, -15964, -16026, -16083, -16135, -16182, -16225, -16262, -16294, -16322, -16344, -16362, -16374, -16382, -16384, -16382, -16374, -16362, -16344, -16322, -16294, -16262, -16225, -16182, -16135, -16083, -16026, -15964, -15897, -15826, -15749, -15668, -15582, -15491, -15396, -15296, -15191, -15082, -14968, -14849, -14726, -14598, -14466, -14330, -14189, -14044, -13894, -13741, -13583, -13421, -13255, -13085, -12911, -12733, -12551, -12365, -12176, -11982, -11786, -11585, -11381, -11174, -10963, -10749, -10531, -10311, -10087, -9860, -9630, -9397, -9162, -8923, -8682, -8438, -8192, -7943, -7692, -7438, -7182, -6924, -6664, -6402, -6138, -5872, -5604, -5334, -5063, -4790, -4516, -4240, -3964, -3686, -3406, -3126, -2845, -2563, -2280, -1997, -1713, -1428, -1143, -857, -572, -286, 0, 286, 572, 857, 1143, 1428, 1713, 1997, 2280, 2563, 2845, 3126, 3406, 3686, 3964, 4240, 4516, 4790, 5063, 5334, 5604, 5872, 6138, 6402, 6664, 6924, 7182, 7438, 7692, 7943, 8192, 8438, 8682, 8923, 9162, 9397, 9630, 9860, 10087, 10311, 10531, 10749, 10963, 11174, 11381, 11585, 11786, 11982, 12176, 12365, 12551, 12733, 12911, 13085, 13255, 13421, 13583, 13741, 13894, 14044, 14189, 14330, 14466, 14598, 14726, 14849, 14968, 15082, 15191, 15296, 15396, 15491, 15582, 15668, 15749, 15826, 15897, 15964, 16026, 16083, 16135, 16182, 16225, 16262, 16294, 16322, 16344, 16362, 16374, 16382
