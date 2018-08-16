;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;"Vector balls" avec de BOBs de 16 x 16 pixels en 4 couleurs.

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DEBUG=0
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
BOB_X=DISPLAY_DX>>1
BOB_Y=DISPLAY_DY>>1
BOB_DX=16
BOB_DY=16
BOB_DEPTH=DISPLAY_DEPTH
SIDE=100
DEPTH=150			;Distance entre l'observateur et l'écran
NBBOBS=35
ROTATEX=1
ROTATEY=2
ROTATEZ=1
TRANSLATEZ=200		;Distance entre l'observateur et l'origine du repère

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

	lea bob+BOB_DEPTH*BOB_DY*(BOB_DX>>3),a1
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

	;Boucle principale

_loop:

	;Attendre la fin du tracé de l'écran

	move.w #DISPLAY_Y+DISPLAY_DY,d0
	bsr _waitRaster

	;Déboguage : passer la couleur du fond à rouge au début de la boucle

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

	;Effacer le back buffer

	move.w #0,BLTDMOD(a5)
	move.w #$0100,BLTCON0(a5)	;USEA=0, USEB=0, USEC=0, USED=1, D=0
	move.w #$0000,BLTCON1(a5)
	move.l backBuffer,BLTDPTH(a5)
	move.w #((DISPLAY_DEPTH*DISPLAY_DY)<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Appliquer une rotation autour de l'axe Z aux points

	move.w angleZ,d0
	lea sinus,a0
	move.w (a0,d0.w),d1
	lea cosinus,a0
	move.w (a0,d0.w),d0
	lea bobs3D,a0
	lea bobs2D,a1
	moveq #NBBOBS-1,d2
_rotateZ:
	move.w (a0),d3
	move.w d3,d4

	muls d0,d3
	swap d3
	rol.l #2,d3			;D3=X*COS

	muls d1,d4
	swap d4
	rol.l #2,d4			;D4=X*SIN

	move.w 2(a0),d5
	move.w d5,d6

	muls d0,d5
	swap d5
	rol.l #2,d5			;D5=Y*COS

	muls d1,d6
	swap d6
	rol.l #2,d6			;D6=Y*SIN

	add.w d6,d3
	move.w d3,(a1)+		;X*COS+Y*SIN
	sub.w d4,d5
	move.w d5,(a1)+		;-X*SIN+Y*COS
	move.w 4(a0),(a1)+
	lea 6(a0),a0
	dbf d2,_rotateZ

	;Appliquer une rotation autour de l'axe Y aux points
	
	move.w angleY,d0
	lea sinus,a0
	move.w (a0,d0.w),d1
	lea cosinus,a0
	move.w (a0,d0.w),d0
	lea bobs2D,a0
	lea bobs2D,a1
	moveq #NBBOBS-1,d2
_rotateY:
	move.w (a0),d3
	move.w d3,d4

	muls d0,d3
	swap d3
	rol.l #2,d3			;D3=X*COS

	muls d1,d4
	swap d4
	rol.l #2,d4			;D4=X*SIN

	move.w 4(a0),d5
	move.w d5,d6

	muls d0,d5
	swap d5
	rol.l #2,d5			;D5=Z*COS

	muls d1,d6
	swap d6
	rol.l #2,d6			;D6=Z*SIN

	add.w d6,d3
	move.w d3,(a1)+		;X*COS+Z*SIN
	move.w 2(a0),(a1)+
	sub.w d4,d5
	move.w d5,(a1)+		;-X*SIN+Z*COS
	lea 6(a0),a0
	dbf d2,_rotateY

	;Projeter les points

	lea bobs2D,a0
	moveq #NBBOBS-1,d0
_project:
	move.w 4(a0),d1
	addi.w #TRANSLATEZ,d1

	move.w (a0),d2
	muls #DEPTH,d2
	divs d1,d2
	addi.w #DISPLAY_DX>>1,d2
	move.w d2,(a0)+

	move.w (a0),d2
	muls #DEPTH,d2
	divs d1,d2
	addi.w #DISPLAY_DY>>1,d2
	move.w d2,(a0)+

	lea 2(a0),a0
	dbf d0,_project

	;Déboguage : Tracer des lignes entre les BOBs formant un cube (à faire avant le tri !)

	movea.l backBuffer,a2

	lea bobs2D+27*3*2,a0
	lea 6(a0),a1
	bsr _drawLine
	movea.l a1,a0
	lea 6(a1),a1
	bsr _drawLine
	movea.l a1,a0
	lea 6(a1),a1
	bsr _drawLine
	lea bobs2D+27*3*2,a0
	bsr _drawLine

	lea bobs2D+31*3*2,a0
	lea 6(a0),a1
	bsr _drawLine
	movea.l a1,a0
	lea 6(a1),a1
	bsr _drawLine
	movea.l a1,a0
	lea 6(a1),a1
	bsr _drawLine
	lea bobs2D+31*3*2,a0
	bsr _drawLine

	lea bobs2D+27*3*2,a0
	lea bobs2D+31*3*2,a1
	bsr _drawLine
	lea 6(a0),a0
	lea 6(a1),a1
	bsr _drawLine
	lea 6(a0),a0
	lea 6(a1),a1
	bsr _drawLine
	lea 6(a0),a0
	lea 6(a1),a1
	bsr _drawLine

	;Trier les points par ordre de profondeur décroissante (ie : du plus éloigné au plus proche)

	lea bobs2D+(NBBOBS-1)*3*2+2*2,a0
	moveq #NBBOBS-2,d0
	moveq #NBBOBS-2,d1
_bubbleSortBackward:
	lea bobs2D+2*2,a1
	move.w d1,d2
_bubbleSortForward:
	move.w (a1),d3
	cmp.w (a0),d3
	bge _bubbleSortSkip
	move.w (a0),(a1)
	move.w d3,(a0)
	move.l -4(a1),d3
	move.l -4(a0),-4(a1)
	move.l d3,-4(a0)
_bubbleSortSkip:
	lea 3*2(a1),a1
	dbf d2,_bubbleSortForward
	subq.w #1,d1
	lea -3*2(a0),a0
	dbf d0,_bubbleSortBackward

	;Animer les angles (rotation dans le sens des aiguilles d'une montre)

	move.w angleX,d0
	subi.w #ROTATEX<<1,d0
	bge _angleXNoUnderflow
	addi.w #360<<1,d0
_angleXNoUnderflow:
	move.w d0,angleX

	move.w angleY,d0
	subi.w #ROTATEY<<1,d0
	bge _angleYNoUnderflow
	addi.w #360<<1,d0
_angleYNoUnderflow:
	move.w d0,angleY

	move.w angleZ,d0
	subi.w #ROTATEZ<<1,d0
	bge _angleZNoUnderflow
	addi.w #360<<1,d0
_angleZNoUnderflow:
	move.w d0,angleZ

	;Dessiner les BOBs

	lea bobs2D,a0
	moveq #NBBOBS-1,d2
_drawBobs:
	moveq #0,d1
	move.w (a0)+,d0
	subi.w #BOB_DX>>1,d0
	move.w d0,d1
	and.w #$F,d0
	ror.w #4,d0
	move.w d0,BLTCON1(a5)		;BSH3-0=décalage
	or.w #$0FF2,d0				;ASH3-0=décalage, USEA=1, USEB=1, USEC=1, USED=1, D=A+bC
	move.w d0,BLTCON0(a5)
	lsr.w #3,d1
	and.b #$FE,d1
	move.w (a0)+,d0
	subi.w #BOB_DY>>1,d0
	mulu #DISPLAY_DEPTH*(DISPLAY_DX>>3),d0
	add.l d1,d0
	move.l backBuffer,d1
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
	lea 2(a0),a0
	dbf d2,_drawBobs

	;Déboguage : passer la couleur du fond à vert à la fin de l'affichage

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

;---------- Tracé de ligne dans un bitplane (au CPU) ----------

;Entrée(s) :
;	A0 = Adresse des coordonnées (X, Y) du point A
;	A1 = Adresse des coordonnées (X, Y) du point B
;	A2 = Adresse du bitplane
;Sortie(s) :
;	(aucune)
;Notice :
;	Cette routine est une simple factorisation. Elle utilise des registres sans les préserver et fait référence à des constantes. Aucune optimisation, pour déboguage uniquement.

_drawLine:
	move.w (a0),d0
	move.w d0,d1	;D1 = X
	move.w d0,d2
	lsr.w #3,d2
	lea (a2,d2.w),a3
	not.b d0
	and.b #$7,d0	;D0 = pixel
	move.w 2(a0),d2	;D2 = Y
	move.w d2,d3
	mulu #DISPLAY_DEPTH*(DISPLAY_DX>>3),d3
	add.l d3,a3

	moveq #1,d3		;D3 = incrément X
	sub.w (a1),d1
	bge _DXPositive
	neg.w d1
	neg.w d3
_DXPositive:
	addq.w #1,d1	;D1 = |xI - xF| + 1 = DX

	move.w #-DISPLAY_DEPTH*(DISPLAY_DX>>3),d4		;D4 = incrément Y
	sub.w 2(a1),d2
	bge _DYPositive
	neg.w d2
	neg.w d4
_DYPositive:
	addq.w #1,d2	;D2 = |yI - yF| + 1 = DY

	cmp.w d2,d1
	bgt _DXGreaterThanDY

	move.w d2,d6
	move.w d1,d5
	lsr.w #1,d5		;D5 = accumulateur
_drawLineY:
	bset d0,(a3)
	add.w d1,d5
	cmp.w d2,d5
	blt _drawLineYNoX
	add.b d3,d0
	bge _drawLineYNoByteUnderflow
	moveq #7,d0
	lea 1(a3),a3
	bra _drawLineYNoByteOverflow
_drawLineYNoByteUnderflow:
	cmpi.b #7,d0
	ble _drawLineYNoByteOverflow
	moveq #0,d0
	lea -1(a3),a3
_drawLineYNoByteOverflow:
	sub.w d2,d5
_drawLineYNoX:
	lea (a3,d4.w),a3
	subq.w #1,d6
	bne _drawLineY
	bra _drawLineDone

_DXGreaterThanDY:
	move.w d1,d6
	move.w d2,d5
	lsr.w #1,d5		;D5 = accumulateur
_drawLineX:
	bset d0,(a3)
	add.w d2,d5
	cmp.w d1,d5
	blt _drawLineXNoY
	lea (a3,d4.w),a3
	sub.w d1,d5
_drawLineXNoY:
	add.b d3,d0
	bge _drawLineXNoByteUnderflow
	moveq #7,d0
	lea 1(a3),a3
	bra _drawLineXNoByteOverflow
_drawLineXNoByteUnderflow:
	cmpi.b #7,d0
	ble _drawLineXNoByteOverflow
	moveq #0,d0
	lea -1(a3),a3
_drawLineXNoByteOverflow:
	subq.w #1,d6
	bne _drawLineX

_drawLineDone:
	rts

;********** Données **********

graphicsLibrary:	DC.B "graphics.library",0
					EVEN
dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
vectors:			BLK.L 6
copperList:			DC.L 0
bitplanesA:			DC.L 0
bitplanesB:			DC.L 0
backBuffer:			DC.L 0
frontBuffer:		DC.L 0
bobMask:
					BLK.W BOB_DEPTH*BOB_DY*((BOB_DX+16)>>4),0
bob:
					INCBIN "SOURCES:spritesAndBobs/ballBlue16x16x2.rawb"
angleX:				DC.W 0
angleY:				DC.W 0
angleZ:				DC.W 0
bobs3D:
					DC.W 0, 0,SIDE
					DC.W 0, 0, 3*SIDE/4
					DC.W 0, 0, SIDE/2
					DC.W 0, 0, SIDE/4
					DC.W 0, 0, 0
					DC.W 0, 0, -SIDE/4
					DC.W 0, 0, -SIDE/2
					DC.W 0, 0, -(3*SIDE)/4
					DC.W 0, 0, -SIDE
					DC.W -SIDE, 0, 0
					DC.W -(3*SIDE)/4, 0, 0
					DC.W -SIDE/2, 0, 0
					DC.W -SIDE/4, 0, 0
					DC.W 0, 0, 0
					DC.W SIDE/4, 0, 0
					DC.W SIDE/2, 0, 0
					DC.W (3*SIDE)/4, 0, 0
					DC.W SIDE, 0, 0
					DC.W 0, -SIDE, 0
					DC.W 0, -(3*SIDE)/4, 0
					DC.W 0, -SIDE/2, 0
					DC.W 0, -SIDE/4, 0
					DC.W 0, 0, 0
					DC.W 0, SIDE/4, 0
					DC.W 0, SIDE/2, 0
					DC.W 0, (3*SIDE)/4, 0
					DC.W 0, SIDE, 0
					DC.W SIDE/2, SIDE/2, -SIDE/2
					DC.W SIDE/2, -SIDE/2, -SIDE/2
					DC.W -SIDE/2, -SIDE/2, -SIDE/2
					DC.W -SIDE/2, SIDE/2, -SIDE/2
					DC.W SIDE/2, SIDE/2, SIDE/2
					DC.W SIDE/2, -SIDE/2, SIDE/2
					DC.W -SIDE/2, -SIDE/2, SIDE/2
					DC.W -SIDE/2, SIDE/2, SIDE/2
bobs2D:
					BLK.W NBBOBS*3,0
sinus:				DC.W 0, 286, 572, 857, 1143, 1428, 1713, 1997, 2280, 2563, 2845, 3126, 3406, 3686, 3964, 4240, 4516, 4790, 5063, 5334, 5604, 5872, 6138, 6402, 6664, 6924, 7182, 7438, 7692, 7943, 8192, 8438, 8682, 8923, 9162, 9397, 9630, 9860, 10087, 10311, 10531, 10749, 10963, 11174, 11381, 11585, 11786, 11982, 12176, 12365, 12551, 12733, 12911, 13085, 13255, 13421, 13583, 13741, 13894, 14044, 14189, 14330, 14466, 14598, 14726, 14849, 14968, 15082, 15191, 15296, 15396, 15491, 15582, 15668, 15749, 15826, 15897, 15964, 16026, 16083, 16135, 16182, 16225, 16262, 16294, 16322, 16344, 16362, 16374, 16382, 16384, 16382, 16374, 16362, 16344, 16322, 16294, 16262, 16225, 16182, 16135, 16083, 16026, 15964, 15897, 15826, 15749, 15668, 15582, 15491, 15396, 15296, 15191, 15082, 14968, 14849, 14726, 14598, 14466, 14330, 14189, 14044, 13894, 13741, 13583, 13421, 13255, 13085, 12911, 12733, 12551, 12365, 12176, 11982, 11786, 11585, 11381, 11174, 10963, 10749, 10531, 10311, 10087, 9860, 9630, 9397, 9162, 8923, 8682, 8438, 8192, 7943, 7692, 7438, 7182, 6924, 6664, 6402, 6138, 5872, 5604, 5334, 5063, 4790, 4516, 4240, 3964, 3686, 3406, 3126, 2845, 2563, 2280, 1997, 1713, 1428, 1143, 857, 572, 286, 0, -286, -572, -857, -1143, -1428, -1713, -1997, -2280, -2563, -2845, -3126, -3406, -3686, -3964, -4240, -4516, -4790, -5063, -5334, -5604, -5872, -6138, -6402, -6664, -6924, -7182, -7438, -7692, -7943, -8192, -8438, -8682, -8923, -9162, -9397, -9630, -9860, -10087, -10311, -10531, -10749, -10963, -11174, -11381, -11585, -11786, -11982, -12176, -12365, -12551, -12733, -12911, -13085, -13255, -13421, -13583, -13741, -13894, -14044, -14189, -14330, -14466, -14598, -14726, -14849, -14968, -15082, -15191, -15296, -15396, -15491, -15582, -15668, -15749, -15826, -15897, -15964, -16026, -16083, -16135, -16182, -16225, -16262, -16294, -16322, -16344, -16362, -16374, -16382, -16384, -16382, -16374, -16362, -16344, -16322, -16294, -16262, -16225, -16182, -16135, -16083, -16026, -15964, -15897, -15826, -15749, -15668, -15582, -15491, -15396, -15296, -15191, -15082, -14968, -14849, -14726, -14598, -14466, -14330, -14189, -14044, -13894, -13741, -13583, -13421, -13255, -13085, -12911, -12733, -12551, -12365, -12176, -11982, -11786, -11585, -11381, -11174, -10963, -10749, -10531, -10311, -10087, -9860, -9630, -9397, -9162, -8923, -8682, -8438, -8192, -7943, -7692, -7438, -7182, -6924, -6664, -6402, -6138, -5872, -5604, -5334, -5063, -4790, -4516, -4240, -3964, -3686, -3406, -3126, -2845, -2563, -2280, -1997, -1713, -1428, -1143, -857, -572, -286
cosinus:			DC.W 16384, 16382, 16374, 16362, 16344, 16322, 16294, 16262, 16225, 16182, 16135, 16083, 16026, 15964, 15897, 15826, 15749, 15668, 15582, 15491, 15396, 15296, 15191, 15082, 14968, 14849, 14726, 14598, 14466, 14330, 14189, 14044, 13894, 13741, 13583, 13421, 13255, 13085, 12911, 12733, 12551, 12365, 12176, 11982, 11786, 11585, 11381, 11174, 10963, 10749, 10531, 10311, 10087, 9860, 9630, 9397, 9162, 8923, 8682, 8438, 8192, 7943, 7692, 7438, 7182, 6924, 6664, 6402, 6138, 5872, 5604, 5334, 5063, 4790, 4516, 4240, 3964, 3686, 3406, 3126, 2845, 2563, 2280, 1997, 1713, 1428, 1143, 857, 572, 286, 0, -286, -572, -857, -1143, -1428, -1713, -1997, -2280, -2563, -2845, -3126, -3406, -3686, -3964, -4240, -4516, -4790, -5063, -5334, -5604, -5872, -6138, -6402, -6664, -6924, -7182, -7438, -7692, -7943, -8192, -8438, -8682, -8923, -9162, -9397, -9630, -9860, -10087, -10311, -10531, -10749, -10963, -11174, -11381, -11585, -11786, -11982, -12176, -12365, -12551, -12733, -12911, -13085, -13255, -13421, -13583, -13741, -13894, -14044, -14189, -14330, -14466, -14598, -14726, -14849, -14968, -15082, -15191, -15296, -15396, -15491, -15582, -15668, -15749, -15826, -15897, -15964, -16026, -16083, -16135, -16182, -16225, -16262, -16294, -16322, -16344, -16362, -16374, -16382, -16384, -16382, -16374, -16362, -16344, -16322, -16294, -16262, -16225, -16182, -16135, -16083, -16026, -15964, -15897, -15826, -15749, -15668, -15582, -15491, -15396, -15296, -15191, -15082, -14968, -14849, -14726, -14598, -14466, -14330, -14189, -14044, -13894, -13741, -13583, -13421, -13255, -13085, -12911, -12733, -12551, -12365, -12176, -11982, -11786, -11585, -11381, -11174, -10963, -10749, -10531, -10311, -10087, -9860, -9630, -9397, -9162, -8923, -8682, -8438, -8192, -7943, -7692, -7438, -7182, -6924, -6664, -6402, -6138, -5872, -5604, -5334, -5063, -4790, -4516, -4240, -3964, -3686, -3406, -3126, -2845, -2563, -2280, -1997, -1713, -1428, -1143, -857, -572, -286, 0, 286, 572, 857, 1143, 1428, 1713, 1997, 2280, 2563, 2845, 3126, 3406, 3686, 3964, 4240, 4516, 4790, 5063, 5334, 5604, 5872, 6138, 6402, 6664, 6924, 7182, 7438, 7692, 7943, 8192, 8438, 8682, 8923, 9162, 9397, 9630, 9860, 10087, 10311, 10531, 10749, 10963, 11174, 11381, 11585, 11786, 11982, 12176, 12365, 12551, 12733, 12911, 13085, 13255, 13421, 13583, 13741, 13894, 14044, 14189, 14330, 14466, 14598, 14726, 14849, 14968, 15082, 15191, 15296, 15396, 15491, 15582, 15668, 15749, 15826, 15897, 15964, 16026, 16083, 16135, 16182, 16225, 16262, 16294, 16322, 16344, 16362, 16374, 16382
