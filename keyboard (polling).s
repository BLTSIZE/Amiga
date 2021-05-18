;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr, stashofcode@gmail.com) en 2017.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Lecture d'une touche pressée au clavier (mode polling, adaptation du mode interruption)

;A FAIRE : Sauvegarder $BFEE01 avant de le modifier et le restaurer à la fin ?
;A FAIRE : Le code bloque l'exécution durant quelques lignes rasters pour acquitter auprès du clavier, et ce n'est pas élégant !

DEBUG=0

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_DEPTH=1
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+2*4+4	;10*4				Configuration de l'affichage
										;DISPLAY_DEPTH*2*4	Adresses des bitplanes
										;2*4				Palette
										;4					$FFFFFFFE

;********** Macros **********

WAIT_RASTER:		MACRO
_waitRaster\@:
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmp.w #\1,d0
	bne _waitRaster\@
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

	;Initialisation de la mécanique d'interruption par le CIA A sur réception des bits transmis par le clavier. On choisit de ménager le système d'exploitation en n'inhibant pas la possibilité pour le CIA A de présenter d'autres requêtes d'interruption que celle qui nous intéresse (autrement dit, pas de move.b #$1F,$BFED01 pour commencer)

	tst.b $BFED01				;Acquitter les éventuelles requêtes d'interruption du CIA A dans ICR
	move.b #$88,$BFED01			;Désactiver le masquage de l'interruption SP dans ICR
	and.b #$BF,$BFEE01			;Effacer le bit SPMODE dans CRA pour basculer le CIA A en mode réception des bits transmis par le clavier

;Boucle principale

_loop:

	;Gérer le clavier

	bsr _keyboard

	;Attendre une trame (deux WAIT_RASTER car la boucle met moins d'une ligne raster à s'exécuter)

	WAIT_RASTER DISPLAY_Y+DISPLAY_DY
	WAIT_RASTER DISPLAY_Y+DISPLAY_DY+1

	;Tester la pression du bouton gauche de la souris

	btst #6,$BFE001
	bne _loop

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

	jsr -138(a6)

	;Libérer la mémoire

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	jsr -210(a6)

	movea.l bitplanes,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	jsr -210(a6)

	;Dépiler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Routines **********

	INCLUDE "SOURCES:common/registers.s"

;---------- Gestion du clavier ----------

_keyboard:
	movem.l d0-d2,-(sp)

	;Vérifier dans ICR que la requête est bien générée par le CIA A aur l'événement SP (bascule des 8 bits reçus du clavier dans SDR)

	btst #3,$BFED01
	beq _keyboardNotKeyboard

	;Lire les 8 bits dans SDR et détecter s'il s'agit de la pression ou du relâchement d'une touche

	move.b $BFEC01,d0
	btst #0,d0
	bne _keyboardKeyDown
	move.w #$00F0,d1		;Touche relâchée : couleur vert
	bra _keyboardKeyUp
_keyboardKeyDown:
	move.w #$0F00,d1		;Touche pressée : couleur rouge
_keyboardKeyUp:

	;Changer la couleur de fond si la touche pressée est celle attendue (ESC)

	not.b d0
	lsr.b #1,d0
	cmpi.b #$45,d0
	bne _keyboardNotESC
	move.w d1,COLOR00(a5)
_keyboardNotESC:

	;Acquitter auprès du clavier en maintenant à 0 le signal sur sa ligne KDAT durant 85 us, ce qui s'effectue en positionnant SPMODE à 1 dans CRA ("software must pulse the line low for 85 microseconds to ensure compatibility with all keyboard models" et "the KDAT line is active low [...] a low level (0V) is interpreted as 1"). Pour rappel, une ligne raster, c'est 227,5 cycles de 280 ns, donc 63,7 us, ce qui signifie qu'il faut attendre que le raster ait parcouru deux lignes. Maintenant, ce n'est pas très élégant d'attendre que le raster se balade en se tournant les pouces...

	bset #6,$BFEE01

	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	moveq #2-1,d1
_keyboardWait85us:
	move.l VPOSR(a5),d2
	lsr.l #8,d2
	and.w #$01FF,d2
	cmp.w d0,d2
	beq _keyboardWait85us
	move.w d2,d0
	dbf d1,_keyboardWait85us

	bclr #6,$BFEE01

_keyboardNotKeyboard:
	movem.l (sp)+,d0-d2
	rts

;---------- Inhibition ----------

_rte:
	rte

;********** Données **********

graphicsLibrary:	DC.B "graphics.library",0
					EVEN
graphicsBase:		DC.L 0
view:				DC.L 0
dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
VBRPointer:			DC.L 0
vectors:			BLK.L 6
copperList:			DC.L 0
bitplanes:			DC.L 0

