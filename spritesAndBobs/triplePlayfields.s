;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Affichage en dual-playfield (deux playfields de 2 couleurs chacun) avec un playfield supplémentaire de trois sprites en 16 couleurs réutilisés horizontalement.

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_DX=320		;A quoi il faut rajouter 16 pixels pour permettre le scroll hardware
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DEPTH=4
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+32*4+8*2*4+DISPLAY_DY*(4+(DISPLAY_DX>>4)*2*4)+4
	;10*4									Configuration de l'affichage
	;DISPLAY_DEPTH*2*4						Adresses des bitplanes
	;32*4									Palette (pas limitée à 1<<DISPLAY_DEPTH couleurs car les sprites utilisent plus largement la palette)
	;8*2*4									Sprites
	;DISPLAY_DY*(4+(DISPLAY_DX>>4)*2*4)		Plan de sprites
	;4										$FFFFFFFE
SPRITE_X=DISPLAY_X-1
SPRITE_Y=DISPLAY_Y
SPRITE_DX=16		;Ne peut pas être modifié
SPRITE_DY=32

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

	;Allouer de la mémoire en Chip mise à 0 pour les bitplanes

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX+16)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,bitplanes

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
	move.w #(DISPLAY_DEPTH<<12)!$0600,(a0)+			;DPF=1, COLOR=1
	move.w #BPLCON1,(a0)+
	move.w #$0000,(a0)+
	move.w #BPLCON2,(a0)+
	move.w #$001B,(a0)+								;PF2PRI=0, PF2P2-0=%011, PF1P2-0=%011 (PF2P2 et PF1P2 doivent être à 0 sur A500 sans quoi les playfields ne sont plus visibles. C'est une "fonctionnalité" non documentée du hardware. Voir http://eab.abime.net/showthread.php?t=19676)
	move.w #DDFSTRT,(a0)+
	move.w #((DISPLAY_X-16-17)>>1)&$00FC,(a0)+
	move.w #DDFSTOP,(a0)+
	move.w #((DISPLAY_X-16-17+((((DISPLAY_DX+16)>>4)-1)<<4))>>1)&$00FC,(a0)+
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+
	move.l #$01FC0000,(a0)+

	;Adresse des bitplanes

	move.w #BPL1PTH,d0
	move.l bitplanes,d1
	moveq #DISPLAY_DEPTH-1,d2
_copperListBitplanes:
	move.w d0,(a0)+
	addq.w #$0002,d0
	swap d1
	move.w d1,(a0)+
	move.w d0,(a0)+
	addq.w #$0002,d0
	swap d1
	move.w d1,(a0)+
	addi.l #DISPLAY_DY*((DISPLAY_DX+16)>>3),d1
	dbf d2,_copperListBitplanes

	;Palette (forcée à 32 couleurs indépendamment du nombre de bitplanes, du fait des sprites)

	lea palette,a1
	move.w #COLOR00,d0
	move.w #32-1,d1
_copperListColors:
	move.w d0,(a0)+
	addq.w #2,d0
	move.w (a1)+,(a0)+
	dbf d1,_copperListColors

	;Sprites (tous les sprites sont affichés, donc afficher les sprites inutilisés avec des données nulles)

	move.l #spriteA0,d0
	move.w #SPR0PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR0PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteA1,d0
	move.w #SPR1PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR1PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteB0,d0
	move.w #SPR2PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR2PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteB1,d0
	move.w #SPR3PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR3PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteC0,d0
	move.w #SPR4PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR4PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteC1,d0
	move.w #SPR5PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR5PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteVoid,d0
	move.w #SPR6PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR6PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.l #spriteVoid,d0
	move.w #SPR7PTL,(a0)+
	move.w d0,(a0)+
	move.w #SPR7PTH,(a0)+
	swap d0
	move.w d0,(a0)+

	move.w #(DISPLAY_Y<<8)!$38!$0001,d0		;$38 empiriquement déterminé, mais en fait c'est la valeur de DDFSTRT en lowres (4.5 cycles d'horloge vidéo avant DIWSTRT => $81/2-8.5 car résolution de DIWSTRT est le pixel mais de DDFSTRT est 4 pixels)
	move.w #DISPLAY_DY-1,d1
_copperListSpriteY:
	move.w d0,(a0)+
	move.w #$FFFE,(a0)+
	move.w #((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1),d2
	move.w #SPR0POS,d3
	move.w #(DISPLAY_DX>>4)-1,d4
_copperListSpriteX:
	move.w d3,(a0)+
	move.w d2,(a0)+
	addq.w #8,d3
	move.w d3,(a0)+
	move.w d2,(a0)+
	addq.w #8,d3
	cmpi.w #SPR6POS,d3							;Le sprite 7 n'étant pas utilisable, seuls les couples de sprites 0&1, 2&3 et 3&4 sont utilisés
	bne _copperListSpriteNoReset
	move.w #SPR0POS,d3
_copperListSpriteNoReset:
	addi.w #16>>1,d2
	dbf d4,_copperListSpriteX
	addi.w #$0100,d0
	dbf d1,_copperListSpriteY

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Activer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

	;Rétablir les DMA

	move.w #$83E0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1, SPREN=1

;********** Programme principal **********

;NB: Attention ! le DMA du Blitter n'a pas été activé...

	;Dessiner un damier
;A FAIRE on dessine rien dans les 16 derniers pixels pour l'heure....
	movea.l bitplanes,a0
	lea DISPLAY_DY*((DISPLAY_DX+16)>>3)(a0),a1
	lea DISPLAY_DY*((DISPLAY_DX+16)>>3)(a1),a2
	lea DISPLAY_DY*((DISPLAY_DX+16)>>3)(a2),a3
	move.l #$FFFF0000,d3
	moveq #0,d4
	moveq #-1,d5
	move.w #(DISPLAY_DY>>4)-1,d0
_drawCheckerY:
	move.w #16-1,d1
_drawChecker16:
	moveq #(DISPLAY_DX>>5)-1,d2
_drawCheckerX:
	move.l d3,(a0)+
	move.l d3,(a1)+
	move.l d4,(a2)+
	move.l d4,(a3)+
	dbf d2,_drawCheckerX
	swap d3
	move.w d3,(a0)+
	move.w d3,(a1)+
	swap d3
	swap d4
	move.w d4,(a2)+
	move.w d4,(a3)+
	swap d4
	dbf d1,_drawChecker16
	swap d3
	exg d4,d5
	dbf d0,_drawCheckerY

	;Boucle principale

	moveq #15,d0	;PF1
	moveq #-1,d1
	moveq #0,d2		;PF2
	moveq #1,d3
_loop:

	;Faire scroller les playfields

	move.w d2,d4
	lsl.b #4,d4
	or.b d0,d4
	movea.l copperList,a0
	move.w d4,3*4+2(a0)

	add.b d1,d0
	bge _scrollPF1Positive
	neg.b d1
	add.b d1,d0
	bra _scrollPF1Done
_scrollPF1Positive:
	cmpi.b #15,d0
	ble _scrollPF1Done
	neg.b d1
	add.b d1,d0
_scrollPF1Done:

	add.b d3,d2
	bge _scrollPF2Positive
	neg.b d3
	add.b d3,d2
	bra _scrollPF2Done
_scrollPF2Positive:
	cmpi.b #15,d2
	ble _scrollPF2Done
	neg.b d3
	add.b d3,d2
_scrollPF2Done:

	;Attendre la fin du tracé de l'écran (attendre à la bonne ligne et à la suivante, car l'exécution de la boucle prend moins d'une ligne)

	movem.w d0,-(sp)
	move.w #DISPLAY_Y+DISPLAY_DY,d0
	bsr _waitRaster
	move.w #DISPLAY_Y+DISPLAY_DY+1,d0
	bsr _waitRaster
	movem.w (sp)+,d0

	;Tester le bouton de la souris

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

	movea.l bitplanes,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX+16)>>3,d0
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
bitplanes:			DC.L 0
spriteA0:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)
					;Chiffre 1
					DC.W $7FFC, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $F8FE, $0000
					DC.W $F9FE, $0000
					DC.W $FBFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFBE, $0000
					DC.W $FF3E, $0000
					DC.W $FE3E, $0000
					DC.W $FFFE, $0000
					DC.W $0000, $0000
					;Petits carés
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W 0, 0
spriteA1:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)!$0080
					;Fond transparent
					REPT 16
					DC.W $0000, $0000
					ENDR
					;Petits carrés
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W 0, 0
spriteB0:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)
					;Chiffre 2
					DC.W $0FE0, $0000
					DC.W $1FE0, $0000
					DC.W $1FE0, $0000
					DC.W $1FE0, $0000
					DC.W $1FE0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $07E0, $0000
					DC.W $1FF8, $0000
					DC.W $0000, $0000
					;Petits carrés
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W 0, 0
spriteB1:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)!$0080
					;Fond transparent
					REPT 16
					DC.W $0000, $0000
					ENDR
					;Petits carrés
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W 0, 0
spriteC0:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)
					;Chiffre 3
					DC.W $7FFC, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $F0FE, $0000
					DC.W $F0FE, $0000
					DC.W $00FE, $0000
					DC.W $FFFE, $0000
					DC.W $F800, $0000
					DC.W $F80E, $0000
					DC.W $F80E, $0000
					DC.W $FFFE, $0000
					DC.W $0000, $0000
					;Petits carrés
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W $F0F0, $FF00
					DC.W 0, 0
spriteC1:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)!$0080
					;Fond transparent
					REPT 16
					DC.W $0000, $0000
					ENDR
					;Petits carrés
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W 0, 0
;Ce dernier couple de sprites n'est pas utilisé (sprites 6 et 7)
spriteD0:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)
					;Chiffre 4
					DC.W $7FFC, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $FFFE, $0000
					DC.W $F0FE, $0000
					DC.W $00FE, $0000
					DC.W $00FE, $0000
					DC.W $1FF0, $0000
					DC.W $00FE, $0000
					DC.W $E0FE, $0000
					DC.W $E0FE, $0000
					DC.W $FFFE, $0000
					DC.W $0000, $0000
					;Petits carrés
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $FFFF, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $0000, $FFFF
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $FFFF, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W $0000, $0000
					DC.W 0, 0
spriteD1:			DC.W ((SPRITE_Y&$FF)<<8)!((SPRITE_X&$1FE)>>1)
					DC.W (((SPRITE_Y+SPRITE_DY)&$FF)<<8)!((SPRITE_Y&$100)>>6)!(((SPRITE_Y+SPRITE_DY)&$100)>>7)!(SPRITE_X&$1)!$0080
					;Fond transparent
					REPT 16
					DC.W $0000, $0000
					ENDR
					;Petits carrés
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W $0F0F, $00FF
					DC.W 0, 0
spriteVoid:
					DC.W $0000, $0000
palette:
					DC.W $0000	;COLOR00	;Playfield 1 (bitplanes 1, 3 et 5)
					DC.W $0700	;COLOR01
					DC.W $0070	;COLOR02
					DC.W $0007	;COLOR03
					DC.W $0000	;COLOR04
					DC.W $0000	;COLOR05
					DC.W $0000	;COLOR06
					DC.W $0000	;COLOR07
					DC.W $0000	;COLOR08	;Playfield 2 (bitplanes 2, 4 et 6)
					DC.W $0F00	;COLOR09
					DC.W $00F0	;COLOR10
					DC.W $000F	;COLOR11
					DC.W $0000	;COLOR12
					DC.W $0000	;COLOR13
					DC.W $0000	;COLOR14
					DC.W $0000	;COLOR15
					DC.W $0000	;COLOR16	;Sprites
					DC.W $0FFF	;COLOR17
					DC.W $0F50	;COLOR18
					DC.W $0FA0	;COLOR19
					DC.W $0FF0	;COLOR20
					DC.W $0080	;COLOR21
					DC.W $07C0	;COLOR22
					DC.W $00F0	;COLOR23
					DC.W $000F	;COLOR24
					DC.W $007F	;COLOR25
					DC.W $00FF	;COLOR26
					DC.W $080F	;COLOR27
					DC.W $0F0F	;COLOR28
					DC.W $0F8F	;COLOR29
					DC.W $0000	;COLOR30
					DC.W $0F00	;COLOR31