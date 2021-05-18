;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr, stashofcode@gmail.com) en 2019.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Programme de base pour gérer les boutons et le mouvement de la souris (branchée sur le port 1).

;********** Constantes **********

;Programme

DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_DEPTH=1
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+4
	;10*4						Configuration de l'affichage
	;DISPLAY_DEPTH*2*4			Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*4		Palette
	;4							$FFFFFFFE

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

WAIT_RASTER:		MACRO
	movem.l d0,-(sp)
_waitRaster\@:
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmp.w #\1,d0
	bne _waitRaster\@
	movem.l (sp)+,d0
	ENDM

;********** Initialisations **********

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

	moveq #0,d0			;Default VBR is $0
	movea.l $4,a6
	btst #0,296+1(a6)	;68010+?
	beq _is68000
	lea _getVBR,a5
	jsr -30(a6)			;SuperVisor ()
	move.l d0,VBRPointer
	bra _is68000
_getVBR:
	movec vbr,d0
	rte
_is68000:

	;Couper le système

	jsr -132(a6)		;Forbid ()

	;Allouer de la mémoire en CHIP mise à 0 pour la Copper list

	move.l #COPPERLIST,d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,copperList

	;Allouer de la mémoire en CHIP mise à 0 pour les bitplanes

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,bitplanes

	;Attendre un VERTB (pour éviter que les sprites ne bavent) et couper les interruptions hardware et les DMA

	lea $DFF000,a5
	WAIT_RASTER DISPLAY_Y+DISPLAY_DY
	move.w INTENAR(a5),intena
	move.w #$7FFF,INTENA(a5)
	move.w INTREQR(a5),intreq
	move.w #$7FFF,INTREQ(a5)
	move.w DMACONR(a5),dmacon
	move.w #$07FF,DMACON(a5)

	;Détourner les vecteurs d'interruption

	movea.l VBRPointer,a0
	lea $64(a0),a0
	lea vectors,a1
	REPT 6
	move.l (a0),(a1)+
	move.l #_rte,(a0)+
	ENDR

;---------- Copper list ----------

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
	move.w #((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC,(a0)+
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+

	;Comptabilité OCS avec AGA

	move.w #FMODE,(a0)+
	move.w #$0000,(a0)+

	;Adresses des bitplanes

	move.w #BPL1PTH,d0
	move.l bitplanes,d1
	moveq #DISPLAY_DEPTH-1,d2
_cooperListBitplanes:
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	add.l #DISPLAY_DY*(DISPLAY_DX>>3),d1
	dbf d2,_cooperListBitplanes

	;Palette

	move.w #COLOR00,d1
	moveq #(1<<DISPLAY_DEPTH)-1,d0
_copperListColors:
	move.w d1,(a0)+
	addq.w #1,d1
	move.w #$0000,(a0)+
	dbf d0,_copperListColors

	;Fin

	move.l #$FFFFFFFE,(a0)

	;Activer les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;Démarrer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

;---------- Initialisations ----------

	bsr _kbdSetup
	move.b #0,mouseFlags		;Bit 0 : 1 si le bouton gauche est pressé, sinon 0
								;Bit 1 : 1 si le bouton droit est pressé, sinon 0
								;Bit 2 : 1 si la souris a été déplacée vers le haut, sinon 0
								;Bit 3 : 1 si la souris a été déplacée vers le bas, sinon 0
								;Bit 4 : 1 si la souris a été déplacée sur la gauche, sinon 0
								;Bit 5 : 1 si la souris a été déplacée sur la droite, sinon 0

;---------- Boucle principale ----------

_loop:

	;Attendre le haut de l'écran

	WAIT_RASTER DISPLAY_Y

	;Passer la couleur 00 à rouge si le bouton gauche est pressé

	btst #6,$BFE001
	bne _mouseLButtonReleased
	move.w #$0F00,COLOR00(a5)
	or.b #$01,mouseFlags
	bra _mouseLButtonDone
_mouseLButtonReleased:
	move.w #$0000,COLOR00(a5)
	and.b #$FE,mouseFlags
_mouseLButtonDone:

	;Attendre le 1er quart de l'écran

	WAIT_RASTER DISPLAY_Y+(DISPLAY_DY>>2)

	;Passer la couleur 00 à vert si le bouton droit est pressé

	move.w #$8400,POTGO(a5)
	btst #10,POTGOR(a5)
	bne _mouseRButtonReleased
	move.w #$00F0,COLOR00(a5)
	or.b #$02,mouseFlags
	bra _mouseRButtonDone
_mouseRButtonReleased:
	move.w #$0000,COLOR00(a5)
	and.b #$FD,mouseFlags
_mouseRButtonDone:

	;Attendre le 2ème quart de l'écran

	WAIT_RASTER DISPLAY_Y+(DISPLAY_DY>>1)

	;Lire les valeurs des compteurs de mouvement de la souris

	move.w JOY0DAT(a5),d0

	;Passer la couleur 00 à rouge si la souris est déplacée vers le bas, et à vert si elle est déplacée vers le haut

	and.b #$F3,mouseFlags
	move.w d0,d1
	and.w #$FC00,d1
	beq _mouseNoVMove
	bgt _mouseVMoveDown
	move.w #$00F0,COLOR00(a5)
	or.b #$04,mouseFlags
	bra _mouseVMoveDone
_mouseVMoveDown:
	move.w #$0F00,COLOR00(a5)
	or.b #$08,mouseFlags
	bra _mouseVMoveDone
_mouseNoVMove:
	move.w #$0000,COLOR00(a5)
_mouseVMoveDone:

	;Attendre le 3ème quart de l'écran

	WAIT_RASTER DISPLAY_Y+3*(DISPLAY_DY>>2)
	move.w #$0000,COLOR00(a5)

	;Passer la couleur 00 à rouge si la souris est déplacée sur la gauche, et à vert si elle est déplacée sur la droite

	and.b #$CF,mouseFlags
	move.b d0,d1
	and.b #$FC,d1
	beq _mouseNoHMove
	bgt _mouseHMoveRight
	move.w #$0F00,COLOR00(a5)
	or.b #$10,mouseFlags
	bra _mouseHMoveDone
_mouseHMoveRight:
	move.w #$00F0,COLOR00(a5)
	or.b #$20,mouseFlags
	bra _mouseHMoveDone
_mouseNoHMove:
	move.w #$0000,COLOR00(a5)
_mouseHMoveDone:

	;Réinitialiser les compteurs de mouvement de la souris

	move.w #0,JOYTEST(a5)

	;Boucler tant qu'une touche du clavier n'a pas été pressée

	move.b #$45,d0
	bsr _kbdRead
	tst.b d0
	beq _loop

	WAIT_BLITTER

;********** Finalisations **********

	;Couper les interruptions hardware et les DMA

	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	move.w #$07FF,DMACON(a5)

	;Rétablir les vecteurs d'interruption

	movea.l VBRPointer,a0
	lea $64(a0),a0
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
	jsr -408(a6)		;OpenLibrary ()
	move.l d0,graphicsBase

	movea.l d0,a0
	move.l 38(a0),COP1LCH(a5)
	clr.w COPJMP1(a5)

	;StingRay's stuff

	movea.l view,a1
	move.l graphicsBase,a6
	jsr -222(a6)		;LoadView ()
	jsr -462(a6)		;DisownBlitter ()
	move.l graphicsBase,a1
	movea.l $4,a6
	jsr -414(a6)		;CloseLibrary ()

	;Rétablir le système

	jsr -138(a6)		;Permit ()

	;Libérer la mémoire

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	jsr -210(a6)		;FreeMem ()

	movea.l bitplanes,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	jsr -210(a6)		;FreeMem ()

	;Dépiler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Routines **********

	INCLUDE "SOURCES:common/registers.s"

;---------- Initialisation du clavier (repris de "keyboard (polling).s") ----------

;Entrée(s) :
;	(rien)
;Sortie(s) :
;	(rien)

_kbdSetup:
	tst.b $BFED01				;Acquitter les éventuelles requêtes d'interruption du CIA A dans ICR
	move.b #$88,$BFED01			;Désactiver le masquage de l'interruption SP dans ICR
	and.b #$BF,$BFEE01			;Effacer le bit SPMODE dans CRA pour basculer le CIA A en mode réception des bits transmis par le clavier
	rts

;---------- Gestion du clavier (repris de "keyboard (polling).s" et adapté) ----------

;Entrée(s) :
;	D0 = Code de la touche dont le relâchement doit être testé
;Sortie(s) :
;	D0 = 1 si la touche est relâchée, sinon 0

_kbdRead:
	movem.l d1-d3,-(sp)

	;Vérifier dans ICR que la requête est bien générée par le CIA A aur l'événement SP (bascule des 8 bits reçus du clavier dans SDR)

	btst #3,$BFED01
	bne _kbdKeyboardRequest
	moveq #0,d0
	bra _kbdDone

	;Lire les 8 bits dans SDR et détecter s'il s'agit de la pression ou du relâchement d'une touche

_kbdKeyboardRequest:
	move.b $BFEC01,d1
	btst #0,d1
	bne _kbdKeyDown

	;Touche relâchée : retourner 1 si la touche relâchée est celle attendue, sinon 0

	not.b d1
	lsr.b #1,d1
	cmpi.b d0,d1
	bne _kbdKeyUpNotAwaitedKey
	moveq #1,d0
	bra _kbdAcknowledge
_kbdKeyUpNotAwaitedKey
	moveq #0,d0
	bra _kbdAcknowledge

	;Touche pressée : retourner 0

_kbdKeyDown:
	moveq #0,d0

	;Acquitter auprès du clavier en maintenant à 0 le signal sur sa ligne KDAT durant 85 us, ce qui s'effectue en positionnant SPMODE à 1 dans CRA ("software must pulse the line low for 85 microseconds to ensure compatibility with all keyboard models" et "the KDAT line is active low [...] a low level (0V) is interpreted as 1"). Pour rappel, une ligne raster, c'est 227,5 cycles de 280 ns, donc 63,7 us, ce qui signifie qu'il faut attendre que le raster ait parcouru deux lignes. Maintenant, ce n'est pas très élégant d'attendre que le raster se balade en se tournant les pouces...

_kbdAcknowledge:

	bset #6,$BFEE01

	move.l VPOSR(a5),d1
	lsr.l #8,d1
	and.w #$01FF,d1
	moveq #2-1,d2
_kbdWait85us:
	move.l VPOSR(a5),d3
	lsr.l #8,d3
	and.w #$01FF,d3
	cmp.w d1,d3
	beq _kbdWait85us
	move.w d3,d1
	dbf d2,_kbdWait85us

	bclr #6,$BFEE01

_kbdDone:
	movem.l (sp)+,d1-d3
	rts

;---------- Gestionnaire d'interruption par défaut ----------

_rte:
	rte

;********** Données **********

	SECTION data,DATA		;Créer une autre section DATA_C pour les données qui doivent être en Chip

VBRPointer:			DC.L 0
graphicsLibrary:	DC.B "graphics.library",0
					EVEN
graphicsBase:		DC.L 0
view:				DC.L 0
dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
vectors:			BLK.L 6
copperList:			DC.L 0
bitplanes:			DC.L 0
colors:
					DC.W $0000	;COLOR00	;Playfield 1 (bitplanes 1, 3 et 5)
					DC.W $0FFF	;COLOR01
					DC.W $0000	;COLOR02
					DC.W $0000	;COLOR03
					DC.W $0000	;COLOR04
					DC.W $0000	;COLOR05
					DC.W $0000	;COLOR06
					DC.W $0000	;COLOR07
					DC.W $0000	;COLOR08	;Playfield 2 (bitplanes 2, 4 et 6)
					DC.W $0000	;COLOR09
					DC.W $0000	;COLOR10
					DC.W $0000	;COLOR11
					DC.W $0000	;COLOR12
					DC.W $0000	;COLOR13
					DC.W $0000	;COLOR14
					DC.W $0000	;COLOR15
					DC.W $0000	;COLOR16	;Sprites 0 et 1
					DC.W $0000	;COLOR17
					DC.W $0000	;COLOR18
					DC.W $0000	;COLOR19
					DC.W $0000	;COLOR20	;Sprites 2 et 3
					DC.W $0000	;COLOR21
					DC.W $0000	;COLOR22
					DC.W $0000	;COLOR23
					DC.W $0000	;COLOR24	;Sprites 4 et 5
					DC.W $0000	;COLOR25
					DC.W $0000	;COLOR26
					DC.W $0000	;COLOR27
					DC.W $0000	;COLOR28	;Sprites 6 et 7
					DC.W $0000	;COLOR29
					DC.W $0000	;COLOR30
					DC.W $0000	;COLOR31
font:				INCBIN "SOURCES:data/fonts/fontWobbly8x8x1.raw"
mouseFlags:			DC.B 0
					EVEN
