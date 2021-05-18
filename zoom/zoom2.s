;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Programme d'ajustement du zoom horizontal hardware.

;Le zoom horizontal hardware est rendu possible par une fonctionnalité non documentée : le hardware lisant les données à afficher par blocs de 16 pixels, réduire la valeur de BPLCON1 entre deux lectures permet d'éviter l'affichage du 16ème pixel du bloc qui vient d'être lu (dissimulation).

;Tout l'enjeu est de savoir quand modifier BPLCON1 pour provoquer cette dissimulation : il faut être synchronisé sur la lecture des 16 pixels. Pour cela, on identifie *empiriquement* dans zoom ceux des 40 MOVE par ligne à utiliser pour modifier BPLCON1. On peut noter que si le nombre de bitplanes dépasse 4, l'affichage vole des cycles DMA au Copper qui ne peut plus procéder à 40 MOVE par ligne, si bien que le zoom part en sucette (il serait possible de l'ajuster, mais peut-être pas jusqu'à permettre la dissimulation de 15 colonnes par ligne).

;Il est certainement possible d'avoir une approche plus rigoureuse sur la base d'une exploration du lien entre la chronologie de la lecture de pixels (DDFSTRT) et celle de l'exécution de la Copper list, bref de la chronologie de l'affichage des données et de l'exécution des MOVE. Toutefois, le seul fait qu'entre la lecture des pixels et leur affichage, il s'écoule un nombre non entier de cycles vidéo (4,5 cycles vidéo) renseigne assez sur celui que la sychronisation de ces chronologies ne saurait être simple...

;Pour chaque ligne Y de l'écran, on trouve donc dans la Copper list :
;
;[0]	WAIT ($00 & $FE, Y & $7F)
;[4]	MOVE BPL1MOD
;[8]	MOVE BPL2MOD
;[12]	MOVE BPLCON1
;[16]	WAIT ($3D & $FE, Y & $7F)
;[20]	40 MOVE dont un certain nombre dans BPLCON1, les autres étant l'équivalent de NOP (cf. ZOOM_NOP)

;Les bitplanes auxquels le zoom est appliqué doivent par défaut être décalés de 7 pixels sur la droite. C'est la situation de base, quand aucune colonne de pixels n'est encore dissimulée. Pourquoi 7 et non 15 ? Pour assurer le centrage à l'écran des bitplanes tandis que toujours plus de colonnes sont dissimulées. Cela a un impact sur la largeur de l'image affichée dans ces bitplanes. En effet, pour l'image zoomée reste centrée sur le contenu d'un bitplane non zoomé (ie : que le contenu d'un bitplane zoomé reste centré à l'écran affiché classiquement), il faut que cette image commence à l'abscisse 0 et se termine à l'abscisse 319 - 14 = 305 dans le bitplane. Autrement dit, il faut qu'elle ne s'étale que sur 306 pixels.

;Bien évidemment, on peut songer à faire commencer la lecture des données 16 pixels avant l'affichage pour regagner les 14 pixels perdus. L'image doit alors s'étaler sur 320 pixels à partir de l'abscisse 16 - 7 = 9 dans un bitplane de 336 pixels de large, y laissant donc une bande verticale de 9 pixels de large sur la gauche et une bande verticale de 7 pixels de large inutilisée sur la droite.

;Le zoom est appliqué aux bitplanes impairs uniquement, pour l'exemple (aucun problème pour l'appliquer simulatément aux bitplaines pairs, ou aux bitplanes pairs uniquement) et pour permettre de visualiser les restrictions qu'il induit. Trois bitplanes sont utilisés :

;- Le bitplane 1 contient un motif groupes de 16 pixels dont seuls le 16ème pixel est à 1 : cela permet de visualiser les colonnes de pixels que le zoom permet de dissimuler.

;- Le bitplane 3 est rempli : cela permet de visualiser l'effet du zoom sur une image.

;- Le bitplane 2 est rempli : cela permet de visualiser le décalage des bitplanes zoomés par rapport à un bitplane qui ne l'est pas.

;********** Constantes **********

;Programme

DISPLAY_DEPTH=3
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
ZOOM_STRIPDY=8
ZOOM_DY=16*ZOOM_STRIPDY
ZOOM_X=$3D
ZOOM_Y=DISPLAY_Y+DISPLAY_DY-ZOOM_DY
ZOOM_NOP=$01FE0000
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+ZOOM_DY*(1+1+1+40)*4+4
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
	move.w #$0007,(a0)+
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

	;Zoom (16 bandes de ZOOM_STRIPDY pixels de hauteur : 1ère bande où 15 colonnes sont dissimulées, 2ème bande où 14 colonnes sont dissimulées, etc.)

	move.w #ZOOM_Y<<8,d0
	lea zoom,a1
	moveq #ZOOM_STRIPDY,d1
	clr.w d2
	move.w #ZOOM_DY-1,d3
_zoomLines:

	move.w d0,d4
	or.w #$00!$0001,d4
	move.w d4,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+

	movea.l a1,a2
	move.b (a2)+,d2
	move.w #BPLCON1,(a0)+
	move.w d2,(a0)+

	move.w d0,d4
	or.w #ZOOM_X!$0001,d4
	move.w d4,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+

	move.w d2,d4
	move.w #40-1,d5
_zoomColumns:
	tst.b (a2)+
	beq _zoomNoBPLCON1
	move.w #BPLCON1,(a0)+
	subq.b #$01,d2
	move.w d2,(a0)+
	dbf d5,_zoomColumns
	bra _zoomColumnsDone
_zoomNoBPLCON1:
	move.l #ZOOM_NOP,(a0)+
	dbf d5,_zoomColumns
_zoomColumnsDone:

	addi.w #$0100,d0
	subq.b #1,d1
	bne _zoomColumnsNoNewStrip
	lea 40+1(a1),a1
	moveq #ZOOM_STRIPDY,d1
_zoomColumnsNoNewStrip:

	dbf d3,_zoomLines

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Rétablir les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

	;Dessiner dans le bitplane 2 le motif de 320 pixels permettant de visualiser le décentrage produit par le zoom

	move.w #0,BLTDMOD(a5)
	move.w #$01AA,BLTCON0(a5)	;USEA=0, USEB=0, USEC=0, USED=1, D=C
	move.w #$0000,BLTCON1(a5)
	move.w #$FFFF,BLTCDAT(a5)
	movea.l bitplanes,a0
	lea DISPLAY_DY*(DISPLAY_DX>>3)(a0),a0
	move.l a0,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Dessiner dans le bitplane 3 le motif de 306 pixels permettant de visualiser l'effet du zoom sur une image

	move.w #$01F0,BLTCON0(a5)	;USEA=0, USEB=0, USEC=0, USED=1, D=A
	move.w #$FFFF,BLTAFWM(a5)
	move.w #$C000,BLTALWM(a5)
	move.w #$0000,BLTCON1(a5)
	move.w #$FFFF,BLTADAT(a5)
	movea.l bitplanes,a0
	lea 2*DISPLAY_DY*(DISPLAY_DX>>3)(a0),a0
	move.l a0,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Dessiner dans le bitplane 1 le motif de 306 pixels permettant de repérer les colonnes dissimulées

	move.w #$01F0,BLTCON0(a5)	;USEA=0, USEB=0, USEC=0, USED=1, D=A
	move.w #$0000,BLTCON1(a5)
	move.w #$FFFF,BLTAFWM(a5)
	move.w #$C000,BLTALWM(a5)
	move.w #$0001,BLTADAT(a5)
	movea.l bitplanes,a0
	move.l a0,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Dessiner dans le bitplane 3 des séparateurs permettant de repérer les bandes

	movea.l bitplanes,a0
	lea (3*DISPLAY_DY-ZOOM_DY)*(DISPLAY_DX>>3)(a0),a0
	move.w #16-1,d0
_drawStripBorders:
	REPT 10
	move.l #0,(a0)+
	ENDR
	lea (ZOOM_STRIPDY-1)*(DISPLAY_DX>>3)(a0),a0
	dbf d0,_drawStripBorders

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
colors:				DC.W $0000	;%000
					DC.W $0FFF	;%001
					DC.W $0F00	;%010
					DC.W $0FFF	;%011
					DC.W $0F00	;%100
					DC.W $0FFF	;%101
					DC.W $0777	;%110
					DC.W $0FFF	;%111
zoom:
					DC.B 7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $0007 -> $0007 (0 colonne supprimée)			
					DC.B 8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $0008 -> $0007 (1 colonne supprimée)
					DC.B 8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $0008 -> $0006 (2 colonnes supprimées)
					DC.B 9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $0009 -> $0006 (3 colonnes supprimées)
					DC.B 9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $0009 -> $0005 (4 colonnes supprimées)
					DC.B 10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000A -> $0005 (5 colonnes supprimées)
					DC.B 10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000A -> $0004 (6 colonnes supprimées)
					DC.B 11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000B -> $0004 (7 colonnes supprimées)
					DC.B 11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000B -> $0003 (8 colonnes supprimées)
					DC.B 12,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000C -> $0003 (9 colonnes supprimées)
					DC.B 12,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000C -> $0002 (10 colonnes supprimées)
					DC.B 13,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0	;BPLCON1 : $000D -> $0002 (11 colonnes supprimées)
					DC.B 13,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0	;BPLCON1 : $000D -> $0001 (12 colonnes supprimées)
					DC.B 14,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,0,0,0,0,0,0,0	;BPLCON1 : $000E -> $0001 (13 colonnes supprimées)
					DC.B 14,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0	;BPLCON1 : $000E -> $0000 (14 colonnes supprimées)
					DC.B 15,0,0,0,0,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,1,0,1,0,1,0,1,0,1,0,0,0,0,0,0	;BPLCON1 : $000F -> $0000 (15 colonnes supprimées)

