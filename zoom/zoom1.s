;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr, stashofcode@gmail.com) en 2018.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Mise en évidence de la possibilité d'un zoom horizontal hardware.

;ZOOM_Y+ZOOM_DY doit être inférieur ou égal à $7F pour une raison expliquée dans l'article "WAIT, SKIP et COMPJMP1 : un usage avancé du Copper (2/2)" qui sera publié dès que la seconde cracktro réalisée pour Scoopex sera distribuée par Galahad...

;********** Constantes **********

;Programme

DISPLAY_DEPTH=2
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
ZOOM_X=$3D
ZOOM_DY=20
ZOOM_Y=DISPLAY_Y+ZOOM_DY
ZOOM_NOP=$01FE0000
ZOOM_MOVE=17
ZOOM_BPLCON1=$0022
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+ZOOM_DY*(1+1+1+40)*4+4+4
	;10*4					Configuration de l'affichage
	;DISPLAY_DEPTH*2*4		Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*4	Palette
	;ZOOM_DY*(1+1+1+40)		Pour chaque ligne zoomée : WAIT, initialisation de BPLCON1, WAIT, 40 MOVE (modification de BPLCON1, et le reste des NOP)
	;4						Réinitialisation de BPLCON1 pour lignes qui suivent celles qui sont zoomées
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

	;Allouer de la mémoire en Chip mise à 0 pour les bitplanes

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,bitplanes

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
	move.w #$00FF,(a0)+
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

	move.l bitplanes,d0
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
	addi.l #DISPLAY_DY*(DISPLAY_DX>>3),d0
	dbf d2,_bitplanes

	;Palette

	lea colors,a1
	moveq #1,d0
	lsl.b #DISPLAY_DEPTH,d0
	subq.b #1,d0
	move.w #COLOR00,d1
_colors:
	move.w d1,(a0)+
	addq.w #2,d1
	move.w (a1)+,(a0)+
	dbf d0,_colors

	;Zoom

	move.w #ZOOM_Y<<8,d0
	move.w #ZOOM_DY-1,d1
_zoomLines:

	;Attendre le début la ligne

	move.w d0,d2
	or.w #$00!$0001,d2
	move.w d2,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+

	;Initialiser BPLCON1 avec une retard de 15 pixels ($00FF)

	move.w #BPLCON1,(a0)+
	move.w #$00FF,(a0)+

	;Attendre la position sur la ligne correspondant au début de l'affichage (position horizontale $3D dans un WAIT)

	move.w d0,d2
	or.w #ZOOM_X!$0001,d2
	move.w d2,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+

	;Enchaîner des MOVE qui ne font rien jusqu'à celui qui doit passer le retard à ZOOM_BPLCON1

	IFNE ZOOM_MOVE		;Car ASM-One plante sur un REPT dont la valeur est 0...
	REPT ZOOM_MOVE
	move.l #ZOOM_NOP,(a0)+
	ENDR
	ENDC

	;Modifier BPLCON1 pour passer le retard à ZOOM_BPLCON1

	move.w #BPLCON1,(a0)+
	move.w #ZOOM_BPLCON1,(a0)+
	
	;Enchaîner des MOVE qui ne font rien jusqu'à la fin de la ligne

	IFNE 39-ZOOM_MOVE		;Car ASM-One plante sur un REPT dont la valeur est 0...
	REPT 39-ZOOM_MOVE
	move.l #ZOOM_NOP,(a0)+
	ENDR
	ENDC

	;Passer à la ligne suivante de la bande de lignes zoomées

	addi.w #$0100,d0
	dbf d1,_zoomLines

	;Réinitialiser BPLCON1 ($00FF) pour la fin de l'écran

	move.w #BPLCON1,(a0)+
	move.w #$00FF,(a0)+

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Rétablir les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

	;Dessiner dans le bitplane 1 un motif (COLOR03) permettant de repérer les colonnes dissimulées :
	;1er mot :  bit 0 à 1    => Dans la 1ère colonne de mots, une colonne blanche de 1 pixel de large identifie les bits 0
	;2ème mot : bits 1-0 à 1 => Dans la 2ème colonne de mots, une colonne blanche de 2 pixels de large identifie les bits 0 et 1
	;3ème mot : bits 2-1 à 1 => Dans la 3ème colonne de mots, une colonne blanche de 3 pixels de large identifie les bits 0, 1 et 2
	;etc.
	;Au-delà du 15ème mot, les mots sont à 0

	move.w #$0000,BLTCON1(a5)
	move.w #$03AA,BLTCON0(a5)		;USEA=0, USEB=0, USEC=1, USED=1, D=C
	move.w #-(DISPLAY_DX>>3),BLTCMOD(a5)
	move.w #0,BLTDMOD(a5)
	move.l #linePattern,BLTCPTH(a5)
	movea.l bitplanes,a0
	move.l a0,BLTDPTH(a5)
	move.w #((3*ZOOM_DY)<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Effacer le bitplane 2 le remplissant de 1 pour distinguer le fond de l'écran (COLOR02) du bord de l'écran (COLOR00)

	move.w #$01AA,BLTCON0(a5)		;USEA=0, USEB=0, USEC=0, USED=1, D=C
	move.w #$0000,BLTCON1(a5)
	move.w #$FFFF,BLTCDAT(a5)
	lea DISPLAY_DY*(DISPLAY_DX>>3)(a0),a0
	move.l a0,BLTDPTH(a5)
	move.w #((3*ZOOM_DY)<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

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

	movea.l bitplanes,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	jsr -210(a6)

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	movea.l $4,a6
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

	SECTION data,DATA

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
colors:				DC.W $0000
					DC.W $00F0
					DC.W $0F00
					DC.W $0FFF
linePattern:		DC.W $0001, $0003, $0007, $000F, $001F, $003F, $007F, $00FF, $01FF, $03FF, $07FF, $0FFF, $1FFF, $3FFF, $7FFF, $0000, $0000, $0000, $0000, $0000
