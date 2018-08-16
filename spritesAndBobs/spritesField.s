;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Répétition des sprites d'une ligne à l'autre sur le principe du fond étoilé (starfield).

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DEPTH=1
COPPERLIST=9*4+DISPLAY_DEPTH*2*4+6*4++8*2*4+4
	;9*4					Configuration de l'affichage
	;DISPLAY_DEPTH*2*4		Adresses des bitplanes
	;6*4					Palette (couleurs 0-1 pour le bitplane, 16-19 pour le sprite)
	;8*2*4					Adresses des sprites
	;4						$FFFFFFFE
STARFIELD_Y=DISPLAY_Y
SPRITE_DX=16				;Ne peut être modifié
SPRITE_DY=16
STARFIELD_NBROWS=15

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

	;Allouer de la mémoire en Chip mise à 0 pour le bitplane

	move.l #(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplane

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
	move.w #$0008,(a0)+			;PF2P2-0=1 => Bitplane de l'unique playfield derrière le sprite 0
	move.w #DDFSTRT,(a0)+
	move.w #((DISPLAY_X-17)>>1)&$00FC,(a0)+
	move.w #DDFSTOP,(a0)+
	move.w #((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC,(a0)+	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+

	;Comptabilité OCS avec AGA

	move.l #$01FC0000,(a0)+

	;Adresse du bitplane

	move.w #BPL1PTL,(a0)+
	move.l bitplane,d0
	move.w d0,(a0)+
	move.w #BPL1PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	;Palette

	move.w #COLOR00,(a0)+
	move.w #$0000,(a0)+
	move.w #COLOR01,(a0)+
	move.w #$0777,(a0)+

	lea spritePalette,a1
	move.w #COLOR16,d0
	moveq #4-1,d1
_palette:
	move.w d0,(a0)+
	addq.w #2,d0
	move.w (a1)+,(a0)+
	dbf d1,_palette

	;Sprites (tous les sprites sont affichés, donc afficher les sprites inutilisés avec des données nulles)

	move.l #spriteData,d0
	move.w #SPR0PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR0PTH,(a0)+
	swap d0
	move.w d0,(a0)+
	move.l #spriteVoid,d0
	move.w #SPR0PTL,d1
	REPT 7
	addq.w #2,d1
	move.w d1,(a0)+
	swap d0
	move.w d0,(a0)+
	addq.w #2,d1
	move.w d1,(a0)+
	swap d0
	move.w d0,(a0)+
	ENDR
	
	;Fin

	move.l #$FFFFFFFE,(a0)

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

	;Rétablir les DMA

	move.w #$83A0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, SPREN=1

;********** Programme principal **********

	;Dessiner un damier

	movea.l bitplane,a0
	move.l #$FFFF0000,d3
	move.w #(DISPLAY_DY>>4)-1,d0
_drawCheckerY:
	move.w #16-1,d1
_drawChecker16:
	moveq #(DISPLAY_DX>>5)-1,d2
_drawCheckerX:
	move.l d3,(a0)+
	dbf d2,_drawCheckerX
	dbf d1,_drawChecker16
	swap d3
	dbf d0,_drawCheckerY

	;Créer les données du sprite décomposé en plusieurs morceaux superposés verticalement (et espacés en cela d'une ligne pour laisser au DMA le temps de charger les nouveaux mots de contrôle dans SPR0POS et SPR0CTL à la fin de chaque morceau du sprite)

	lea spriteData,a0
	lea spritePositions,a1
	move.w #STARFIELD_Y,d1
	move.w #STARFIELD_NBROWS-1,d2
_createSprite:

	move.w (a1),d0
	addi.w #DISPLAY_X,d0
	lea 4(a1),a1

	move.w d1,d3
	lsl.w #8,d3
	move.w d0,d4
	subq.w #1,d4
	lsr.w #1,d4
	move.b d4,d3
	move.w d3,(a0)+		;((SPRITE_Y&$FF)<<8)!(((SPRITE_X-1)&$1FE)>>1)

	move.w d1,d3
	addi.w #SPRITE_DY,d3
	move.w d3,d5
	lsl.w #8,d3
	move.w d1,d4
	lsr.w #6,d4
	and.b #$04,d4
	move.b d4,d3
	lsr.w #7,d5
	and.b #$02,d5
	or.b d5,d3
	move.w d0,d4
	subq.w #1,d4
	and.b #$01,d4
	or.b d4,d3
	move.w d3,(a0)+		;(((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!((SPRITE_X-1)&$1)

	lea spriteBitmap,a2
	REPT SPRITE_DY
	move.l (a2)+,(a0)+
	ENDR

	addi.w #SPRITE_DY+1,d1	;Il faut laisser une ligne au DMA

	dbf d2,_createSprite

	move.l #$00000000,(a0)+

	;Boucle principale

_loop:

	;Mettre à jour la position des morceaux du sprite horizontalement

	lea spriteData,a0
	lea spritePositions,a1
	move.w #STARFIELD_Y,d1
	move.w #STARFIELD_NBROWS-1,d2
_updateSprites:

	move.w (a1),d0
	addi.w #DISPLAY_X,d0
	lea 4(a1),a1

	move.w d1,d3
	lsl.w #8,d3
	move.w d0,d4
	subq.w #1,d4
	lsr.w #1,d4
	move.b d4,d3
	move.w d3,(a0)+		;((SPRITE_Y&$FF)<<8)!(((SPRITE_X-1)&$1FE)>>1)

	move.w d1,d3
	addi.w #SPRITE_DY,d3
	move.w d3,d5
	lsl.w #8,d3
	move.w d1,d4
	lsr.w #6,d4
	and.b #$04,d4
	move.b d4,d3
	lsr.w #7,d5
	and.b #$02,d5
	or.b d5,d3
	move.w d0,d4
	subq.w #1,d4
	and.b #$01,d4
	or.b d4,d3
	move.w d3,(a0)+		;(((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!((SPRITE_X-1)&$1)

	lea SPRITE_DY*4(a0),a0
	addi.w #SPRITE_DY+1,d1	;Il faut laisser une ligne au DMA

	dbf d2,_updateSprites

	;Déplacer horizontalement les morceaux du sprite

	lea spritePositions,a0
	move.w #STARFIELD_NBROWS-1,d0
_moveSprites:
	move.w (a0),d1
	add.w 2(a0),d1
	cmpi.w #-SPRITE_DX,d1
	bge _noUnderflowX
	addi.w #DISPLAY_DX+SPRITE_DX,d1
	bra _noOverflowX
_noUnderflowX:
	cmpi.w #DISPLAY_DX,d1
	ble _noOverflowX
	subi.w #DISPLAY_DX+SPRITE_DX,d1
_noOverflowX:
	move.w d1,(a0)
	lea 4(a0),a0
	dbf d0,_moveSprites

	;Attendre la fin du tracé de l'écran (attendre à la bonne ligne et à la suivante, car l'exécution de la boucle prend moins d'une ligne)

	movem.w d0,-(sp)
	move.w #DISPLAY_Y+DISPLAY_DY,d0
	bsr _waitRaster
	move.w #DISPLAY_Y+DISPLAY_DY+1,d0
	bsr _waitRaster
	movem.w (sp)+,d0

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

	movea.l bitplane,a1
	move.l #DISPLAY_DY*(DISPLAY_DX>>3),d0
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
bitplane:			DC.L 0
spriteBitmap:
					REPT SPRITE_DY>>1
					DC.W $00FF, $0000
					ENDR
					REPT SPRITE_DY>>1
					DC.W $00FF, $FFFF
					ENDR
spriteVoid:
					DC.W 0, 0
spritePalette:
					DC.W $0000, $0F00, $00F0, $000F
spriteData:
					BLK.W STARFIELD_NBROWS*(1+SPRITE_DY)*2+2, 0
spritePositions:	;Il faut STARFIELD_NBROWS lignes. Le premier mot est la position horizontale (exprimée dans le repère de l'écran, donc ajouter DISPLAY_X pour l'utiliser), le second la vitesse horizontale (générées aléatoirement)
					DC.W 164, 4
					DC.W 129, 2
					DC.W 68, 5
					DC.W 192, 3
					DC.W 84, 2
					DC.W 144, 5
					DC.W 127, 1
					DC.W 21, 1
					DC.W 71, 2
					DC.W 182, 2
					DC.W 20, 2
					DC.W 120, 2
					DC.W 222, 4
					DC.W 97, 5
					DC.W 5, 5
