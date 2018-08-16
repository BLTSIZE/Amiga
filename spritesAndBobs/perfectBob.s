;Cod� par Denis Duplan pour Stash of Code (http://www.stashofcode.fr) en 2018.

;Ce(tte) oeuvre est mise � disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d�Utilisation Commerciale 4.0 International.

;Affichage et d�placement d'un BOB de 64 x 64 pixels (dimensions modifiables via les constantes BOB_DX et BOB_DY, pourvu que BOB_DX soit multiple de 16) en 32 couleurs sur un fond compos� de 5 bitplanes en mode RAW Blitter, avec masquage. Contrairement � bobRAWB.s, le fond est restaur� sur la seule zone rectangulaire qu'occupait le BOB avant d'�tre d�plac� (recover presque parfait, car si le BOB ne contient pas de pixels transparents car c'est un rectangle, on peut dire que seuls les pixels qu'ils recouvrent sont restaur�s, ce qui est utile pour g�rer du fen�trage)

;Dans la r�alit�, on pourrait parfaitement se contenter de restaurer le fond sans masquer ce dernier. Apr�s tout, si le fond n'a pas chang� entre le moment o� le BOB a �t� affich� et le moment o� ce dernier doit �tre effac�, autant recopier int�gralement les mots de chaque ligne que le BOB recouvrait, m�me partiellement. Ce qui est parfait n'est pas n�cessairement le plus indiqu�, car ce n'est toujours le plus efficace :) J'ai donc rajout� une version de _clearBOB optimis�e, _clearBOBFast. Utiliser la constante CLEARFAST pour alterner entre _clearBOB et _clearBOBFAst.

;********** Directives **********

	SECTION yragael,CODE_C

;********** Constantes **********

;Programme

DISPLAY_X=$81
DISPLAY_Y=$2C
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_DEPTH=5
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*2*4+4
	;10*4						Configuration de l'affichage
	;DISPLAY_DEPTH*2*4			Adresses des bitplanes
	;(1<<DISPLAY_DEPTH)*2*4		Palette
	;4							$FFFFFFFE
DEBUG=1			;0 : Afficher le temps consomm� en passant la couleur 0 � rouge durant les calculs
				;1 : Ne pas afficher le temps consomm�
CLEARFAST=1		;0 : Utiliser _clearBOB (ie : restaurer le fond au plus juste)
				;1 : Utiliser _clearBOBFast (ie : restaurer le fond au plus large)

;********** Macros **********

;Attendre le Blitter. Quand la seconde op�rande est une adresse, BTST ne permet de tester que les bits 7-0 de l'octet point�, mais traitant la premi�re op�rande comme le num�ro du bit modulo 8, BTST #14,DMACONR(a5) revient � tester le bit 14%8=6 de l'octet de poids fort de DMACONR, ce qui correspond bien � BBUSY...

WAIT_BLITTER:	MACRO
_WAIT_BLITTER0\@
	btst #14,DMACONR(a5)
	bne _WAIT_BLITTER0\@
_WAIT_BLITTER1\@
	btst #14,DMACONR(a5)
	bne _WAIT_BLITTER1\@
	ENDM

;********** Initialisations **********

	;Empiler les registres

	movem.l d0-d7/a0-a6,-(sp)
	lea $DFF000,a5

	;Allouer de la m�moire en CHIP mise � 0 pour la Copper list

	move.l #COPPERLIST,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,copperList

	;Allouer de la m�moire en Chip mise � 0 pour le fond (background)

	move.l #DISPLAY_DEPTH*(DISPLAY_DX*DISPLAY_DY)>>3,d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,background

	;Allouer de la m�moire en Chip mise � 0 pour les bitplanes affich�s (front buffer)

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,frontBuffer

	;Allouer de la m�moire en Chip mise � 0 pour les bitplanes de travail (back buffer)

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	movea.l $4,a6
	jsr -198(a6)
	move.l d0,backBuffer

	;Couper le syst�me

	movea.l $4,a6
	jsr -132(a6)

	;Attendre un VERTB (pour �viter que les sprites ne bavent) et couper les interruptions hardware et les DMA

	bsr _waitVERTB
	move.w INTENAR(a5),intena
	move.w #$7FFF,INTENA(a5)
	move.w INTREQR(a5),intreq
	move.w #$7FFF,INTREQ(a5)
	move.w DMACONR(a5),dmacon
	move.w #$07FF,DMACON(a5)

	;---------- Copper list ----------

	movea.l copperList,a0

	;Configuration de l'�cran

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
	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #(DISPLAY_DEPTH-1)*(DISPLAY_DX>>3),(a0)+

	;Comptabilit� OCS avec AGA

	move.w #FMODE,(a0)+
	move.w #$0000,(a0)+

	;Adresses des bitplanes

	move.w #BPL1PTH,d0
	move.l frontBuffer,d1
	moveq #DISPLAY_DEPTH-1,d2
_copperListBitplanes:
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	move.w d0,(a0)+
	swap d1
	move.w d1,(a0)+
	addq.w #2,d0
	addi.l #DISPLAY_DX>>3,d1
	dbf d2,_copperListBitplanes

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

	;Activer les DMA

	bsr _waitVERTB
	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;D�marrer la Copper list

	move.l copperList,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

BOB_DX=64		;Multiple de 16 (uniquement pour _drawBOB, car _clearBOB est plus souple : voir sa notice)
BOB_DY=64
BOB_X=(DISPLAY_DX-BOB_DX)>>1
BOB_Y=(DISPLAY_DY-BOB_DY)>>1

	;Dessiner le fond � base de carr�s de 16 x 16 de couleurs successives rebouclant sur la couleur 0

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

	;Cr�er le BOB en recopiant une partie du fond tout en la combinant au masque (�tape requise, car il faut que les pixels transparents du BOB soient effectivement transparents dans ce dernier, le masque n'�tant appliqu� qu'au fond lors de l'affichage du BOB : la formule utilis�e dans _drawBOB est D=A+bC et non D=BA+bC)

	move.w #$0788,BLTCON0(a5)		;USEA=0, USEB=1, USEC=1, USED=1, D=BC
	move.w #$0000,BLTCON1(a5)
	move.w #2,BLTBMOD(a5)
	move.w #(DISPLAY_DX-BOB_DX)>>3,BLTCMOD(a5)
	move.w #0,BLTDMOD(a5)
	move.l #BOBMask,BLTBPTH(a5)
	move.l background,BLTCPTH(a5)
	move.l #BOB,BLTDPTH(a5)
	move.w #((DISPLAY_DEPTH*BOB_DY)<<6)!(BOB_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER
	
	;Boucle principale

_loop:

	;Effacer le BOB

	lea clearBOBData,a0
	move.w #DISPLAY_DEPTH,OFFSET_CLEARBOB_DEPTH(a0)
	move.w oldBobX,OFFSET_CLEARBOB_X(a0)
	move.w oldBobY,OFFSET_CLEARBOB_Y(a0)
	move.w #BOB_DX,OFFSET_CLEARBOB_DX(a0)
	move.w #BOB_DY,OFFSET_CLEARBOB_DY(a0)
	move.l background,OFFSET_CLEARBOB_SRC(a0)
	move.l backBuffer,OFFSET_CLEARBOB_DST(a0)
	move.w #DISPLAY_DX,OFFSET_CLEARBOB_SRCDSTWIDTH(a0)
	IFNE CLEARFAST
	bsr _clearBOB
	ELSE
	bsr _clearBOBFast
	ENDC

	;D�placer le BOB
	
	move.w bobX,d0
	move.w d0,oldBobX
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
	move.w d0,oldBobY
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

	;Afficher le BOB

	lea drawBOBData,a0
	move.w #DISPLAY_DEPTH,OFFSET_DRAWBOB_DEPTH(a0)
	move.w bobX,OFFSET_DRAWBOB_X(a0)
	move.w bobY,OFFSET_DRAWBOB_Y(a0)
	move.w #BOB_DX,OFFSET_DRAWBOB_DX(a0)
	move.w #BOB_DY,OFFSET_DRAWBOB_DY(a0)
	move.l #BOBMask,OFFSET_DRAWBOB_MASK(a0)
	move.l #BOB,OFFSET_DRAWBOB_SRC(a0)
	move.w #BOB_DX,OFFSET_DRAWBOB_SRCWIDTH(a0)
	move.w #0,OFFSET_DRAWBOB_SRCX(a0)
	move.w #0,OFFSET_DRAWBOB_SRCY(a0)
	move.l backBuffer,OFFSET_DRAWBOB_DST(a0)
	move.w #DISPLAY_DX,OFFSET_DRAWBOB_DSTWIDTH(a0)
	bsr _drawBOB

	;Permuter les buffers

	WAIT_BLITTER
	IFNE DEBUG
	move.w #$0000,COLOR00(a5)
	ENDC
	moveq #1,d0
	jsr _wait
	IFNE DEBUG
	move.w #$0F00,COLOR00(a5)
	ENDC

	move.l frontBuffer,d0
	move.l backBuffer,d1
	move.l d0,backBuffer
	move.l d1,frontBuffer
	movea.l copperList,a0
	lea 10*4+2(a0),a0
	moveq #DISPLAY_DEPTH-1,d0
	move.l frontBuffer,d1
_swapBitplanes:
	swap d1
	move.w d1,(a0)
	swap d1
	move.w d1,4(a0)
	addi.l #DISPLAY_DX>>3,d1
	lea 2*4(a0),a0
	dbf d0,_swapBitplanes

	;Tester si le bouton gauche de la souris est press�

	btst #6,$BFE001
	bne _loop

;********** Finalisations **********

	;Couper les interruptions hardware et les DMA

	move.w #$7FFF,INTENA(a5)
	move.w #$7FFF,INTREQ(a5)
	move.w #$07FF,DMACON(a5)

	;R�tablir les interruptions hardware et les DMA

	move.w dmacon,d0
	bset #15,d0
	move.w d0,DMACON(a5)
	move.w intreq,d0
	bset #15,d0
	move.w d0,INTREQ(a5)
	move.w intena,d0
	bset #15,d0
	move.w d0,INTENA(a5)

	;R�tablir la Copper list

	lea graphicsLibrary,a1
	movea.l $4,a6
	jsr -408(a6)
	move.l d0,a1
	move.l 38(a1),COP1LCH(a5)
	clr.w COPJMP1(a5)
	jsr -414(a6)

	;R�tablir le syst�me

	movea.l $4,a6
	jsr -138(a6)

	;Lib�rer la m�moire

	movea.l copperList,a1
	move.l #COPPERLIST,d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l background,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l frontBuffer,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	movea.l backBuffer,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	movea.l $4,a6
	jsr -210(a6)

	;D�piler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Routines **********

	INCLUDE "SOURCES:common/registers.s"
	INCLUDE "SOURCES:common/wait.s"

;---------- Effacage d'un BOB dans une surface en RAWB ----------

;Entr�e(s) :
;	(la structure clearBOBData)
;Sortie(s) :
;	(rien)
;Notice:
;	C'est un peu plus que l'effacage d'un BOB, car la largeur de la zone
;	recopi�e de la source dans la destination peut �tre quelconque.
;
;	La largeur de la zone � copier est limit�e � DISPLAY_DX (autrement, il faut
;	modifier la taille de copyMaskData).
;
;	Attention ! Pas de WAIT_BLITTER � la fin.

_clearBOB:
	movem.l d0-d4/a0-a1,-(sp)
	lea clearBOBData,a0

	WAIT_BLITTER

	;++++++++++ Construire le masque (rappel : concernant A, BLTAFWM et BLTALWM seront combin�s par AND si le BOB tient sur un mot) ++++++++++

	;Dans tous les cas, le masque comprend au moins un mot, initialis� par d�faut � $FFFF et comptabilis�. Noter que le nombre de mots ne d�passant certainement pas 255, la comptabilisation s'effectuera sur un octet (ie : des ADDQ.B et non des ADDQ.W par la suite).
	
	lea clearBOBMask,a1
	move.w #$FFFF,(a1)
	moveq #1,d4
	move.w OFFSET_CLEARBOB_X(a0),d0
	move.w OFFSET_CLEARBOB_DX(a0),d1
	move.w d0,d2
	add.w d1,d2

	;D�caler le premier mot du masque si jamais le BOB ne commence pas � une abscisse multiple de 16.

	move.w #$FFFF,d3
	and.w #$000F,d0		;Pour rappel, LSR Dx,Dy = LSR (Dx % 64),Dy : pour LSR (Dx % 16),Dy, il suffirait donc d'effacer les bits 5-4 de D0 par AND.B #$0F,D0, mais D0 va servir pour un ADD.W plus loin, si bien qu'il faut aussi effacer ses 8 bits de poids forts.
	beq _copyAreaNoFirstWordShift
	lsr.w d0,d3
	move.w d3,(a1)
_copyAreaNoFirstWordShift:

	;R�duire le nombre de bits du masque restant � traiter du nombre de bits du masque figurant (ou pouvant figurer, car le masque est peut-�tre moins large) dans le premier mot : DX -= 16 - X. Cette longueur devient nulle ou n�gative si jamais le masque tient le seul premier mot. Dans ce cas, entreprendre directement de d�terminer le dernier mot.

	subi.w #16,d1
	add.w d0,d1
	ble _copyAreaNoMiddleWords

	;A ce stade, on sait que le masque s'�tend au-del� du premier mot, sur au moins un mot supplementaire. Trois cas de figure sont possibles (un mot m�dian est un mot dont tous les bits sont � 1, le mot final est un mot dont seuls certains bits sont � 1) : (1) des mots m�dians sans mot final, (2) des mots m�dians et un mot final, (3) un mot final uniquement. Pour l'heure, comptabiliser un mot de plus et initialiser ce mot � $FFFF.
	
	moveq #2,d4
	addq.l #2,a1
	move.w #$FFFF,(a1)

	;D�nombrer les mots m�dians : c'est la longueur restante divis�e par 16. S'il n'y a pas de mots m�dians, entreprendre directement de d�terminer le dernier mot.

	lsr.w #4,d1
	beq _copyAreaNoMiddleWords

	;Ajouter le nombre de mots m�dians au nombre de mots en consid�rant pour l'heure que le mot final est un mot m�dian, si bien qu'il aurait d�j� �t� comptabilis� plus t�t (MOVEQ #2,d4).

	add.b d1,d4
	subq.b #1,d4

	;Ajouter les mots m�dians, qui sont donc des mot � $FFFF.

	move.w #$FFFF,d0
_copyAreaSetMiddleWords:
	move.w d0,(a1)+
	subq.w #1,d1
	bne _copyAreaSetMiddleWords

	;V�rifier si le mot final n'est pas un mot m�dian...

	and.b #$0F,d2
	beq _copyAreaNoLastWordShift

	;...et si le mot final n'est pas un mot m�dian, comptabiliser un mot de plus et initialiser ce mot � $FFFF. Comme il sera inutile de refaire ce test, entreprendre directement de d�caler le mot final.

	addq.b #1,d4
	move.w #$FFFF,(a1)
	bra _copyAreaShiftLastWord
_copyAreaNoMiddleWords:

	;On arrive ici qu'il y ait des mots m�dians ou non. Le mot courant est le mot final. Il peut �tre confondu avec le premier mot. Si tel n'est pas le cas, il a �t� initialis� � $FFFF. C'est pourquoi le masque calcul� ici est combin� par AND avec le mot courant pour produire le mot final.

	move.w #$FFFF,d0
	and.b #$0F,d2
	beq _copyAreaNoLastWordShift
_copyAreaShiftLastWord:
	lsr.w d2,d0
	not.w d0
	and.w d0,(a1)
_copyAreaNoLastWordShift:

	;Incontournables, ces affectations ont �t� repouss�es � la fin pour ne pas avoir � les faire figurer plusieurs fois dans tout ce qui pr�c�de.

	move.w d0,BLTALWM(a5)
	move.w d3,BLTAFWM(a5)

	;++++++++++ Calculer les pointeurs et les modulos ++++++++++

	;Calculer l'offset les pointeurs de la source et de la destination

	moveq #0,d0
	move.w OFFSET_CLEARBOB_X(a0),d0
	lsr.w #3,d0
	and.b #$FE,d0
	move.w OFFSET_CLEARBOB_SRCDSTWIDTH(a0),d1
	lsr.w #3,d1
	mulu OFFSET_CLEARBOB_DEPTH(a0),d1
	mulu OFFSET_CLEARBOB_Y(a0),d1
	add.l d1,d0

	movea.l OFFSET_CLEARBOB_SRC(a0),a1
	add.l d0,a1
	move.l a1,BLTAPTH(a5)
	movea.l OFFSET_CLEARBOB_DST(a0),a1
	add.l d0,a1
	move.l a1,BLTCPTH(a5)
	move.l a1,BLTDPTH(a5)
	move.l #clearBOBMask,BLTBPTH(a5)

	;Calculer les modulos

	move.w OFFSET_CLEARBOB_SRCDSTWIDTH(a0),d0
	lsr.w #3,d0
	move.w d4,d1
	add.w d1,d1
	sub.w d1,d0
	move.w d0,BLTAMOD(a5)
	move.w d0,BLTCMOD(a5)
	move.w d0,BLTDMOD(a5)
	neg.w d1
	move.w d1,BLTBMOD(a5)

	;++++++++++ Copier ++++++++++

	move.w #$0FF2,BLTCON0(a5)		;ASH3-0=0, USEA=1, USEB=1, USEC=1, USED=1, D=A+bC
	move.w #$0000,BLTCON1(a5)
	move.w OFFSET_CLEARBOB_DY(a0),d1
	mulu OFFSET_CLEARBOB_DEPTH(a0),d1
	lsl.w #6,d1
	or.w d4,d1
	move.w d1,BLTSIZE(a5)

	movem.l (sp)+,d0-d4/a0-a1
	rts

clearBOBData:
OFFSET_CLEARBOB_DEPTH=0
OFFSET_CLEARBOB_X=2
OFFSET_CLEARBOB_Y=4
OFFSET_CLEARBOB_DX=6
OFFSET_CLEARBOB_DY=8
OFFSET_CLEARBOB_SRC=10
OFFSET_CLEARBOB_DST=14
OFFSET_CLEARBOB_SRCDSTWIDTH=18
DATASIZE_CLEARBOB=20
	BLK.B DATASIZE_CLEARBOB,0

clearBOBMask:
	BLK.W DISPLAY_DX>>4,0

;---------- Effacage d'un BOB dans une surface en RAWB (version optimis�e) ----------

;Entr�e(s) :
;	(la structure clearBOBData)
;Sortie(s) :
;	(rien)
;Notice:
;	C'est une version optimis�e de _clearBOB, qui se contente de recopier tous
;	les mots m�me partiellement occup�s par le BOB, sans donc les masquer.
;
;	Attention ! Pas de WAIT_BLITTER � la fin.

_clearBOBFast:
	movem.l d0-d3/a0-a1,-(sp)
	lea clearBOBData,a0

	WAIT_BLITTER

	;Calculer le nombre de mots partiellement ou int�gralement concern�s

	moveq #0,d3
	move.w OFFSET_CLEARBOB_X(a0),d0
	move.w OFFSET_CLEARBOB_DX(a0),d1
	move.w d1,d2
	add.w d0,d2

	and.w #$000F,d0
	beq _clearBOBFastLeftAligned
	moveq #1,d3
	subi.w #16,d1
	add.w d0,d1
	ble _clearBOBFastRightAligned
_clearBOBFastLeftAligned:
	lsr.w #4,d1
	add.b d1,d3
	and.b #$0F,d2
	beq _clearBOBFastRightAligned
	addq.b #1,d3
_clearBOBFastRightAligned:

	;Calculer l'offset des pointeurs de la source et de la destination

	moveq #0,d0
	move.w OFFSET_CLEARBOB_X(a0),d0
	lsr.w #3,d0
	and.b #$FE,d0
	move.w OFFSET_CLEARBOB_SRCDSTWIDTH(a0),d1
	lsr.w #3,d1
	mulu OFFSET_CLEARBOB_DEPTH(a0),d1
	mulu OFFSET_CLEARBOB_Y(a0),d1
	add.l d1,d0

	movea.l OFFSET_CLEARBOB_SRC(a0),a1
	add.l d0,a1
	move.l a1,BLTBPTH(a5)
	movea.l OFFSET_CLEARBOB_DST(a0),a1
	add.l d0,a1
	move.l a1,BLTDPTH(a5)

	;Calculer les modulos

	move.w OFFSET_CLEARBOB_SRCDSTWIDTH(a0),d0
	lsr.w #3,d0
	move.w d3,d1
	add.w d1,d1
	sub.w d1,d0
	move.w d0,BLTBMOD(a5)
	move.w d0,BLTDMOD(a5)

	;Copier

	move.w #$05CC,BLTCON0(a5)		;USEA=0, USEB=1, USEC=0, USED=1, D=B
	move.w #$0000,BLTCON1(a5)
	move.w OFFSET_CLEARBOB_DY(a0),d0
	mulu OFFSET_CLEARBOB_DEPTH(a0),d0
	lsl.w #6,d0
	or.w d3,d0
	move.w d0,BLTSIZE(a5)

	movem.l (sp)+,d0-d3/a0-a1
	rts

;---------- Affichage d'un BOB dans une surface en RAWB ----------

;Entr�e(s) :
;	(la structure drawBOBData)
;Sortie(s) :
;	(rien)
;Notice:
;	Le BOB est d�coup� dans la source � une abscisse multiple de 16, et sa
;	largeur doit �tre multiple de 16.
;
;	La source et la destination doivent avoir la m�me profondeur, et leurs
;	donn�es �tre organis�es en RAWB.
;
;	Le modulo du masque doit �tre � 0 (ie : sa largeur est celle du BOB + 16).
;
;	Attention ! Pas de WAIT_BLITTER � la fin.

_drawBOB:
	movem.l d0-d1/a0-a2,-(sp)
	WAIT_BLITTER

	;Partie factorisable si affichage de multiples BOBs en s�quence

	move.w #$FFFF,BLTAFWM(a5)
	move.w #$0000,BLTALWM(a5)
	lea drawBOBData,a0
	move.w OFFSET_DRAWBOB_SRCWIDTH(a0),d0
	sub.w OFFSET_DRAWBOB_DX(a0),d0
	subi.w #16,d0
	asr.w #3,d0
	move.w d0,BLTAMOD(a5)
	move.w OFFSET_DRAWBOB_DSTWIDTH(a0),d0
	sub.w OFFSET_DRAWBOB_DX(a0),d0
	subi.w #16,d0
	asr.w #3,d0
	move.w d0,BLTCMOD(a5)

	;R�cup�rer un pointeur sur le BOB � ses coordonn�es de d�part (son abscisse est multiple de 16)

	movea.l OFFSET_DRAWBOB_SRC(a0),a1
	moveq #0,d0
	move.w OFFSET_DRAWBOB_SRCX(a0),d0
	lsr.w #3,d0
	and.b #$FE,d0
	add.l d0,a1
	move.w OFFSET_DRAWBOB_SRCY(a0),d0
	move.w OFFSET_DRAWBOB_SRCWIDTH(a0),d1
	lsr.w #3,d1
	mulu OFFSET_DRAWBOB_DEPTH(a0),d1
	mulu d1,d0
	add.l d0,a1

	;R�cup�rer un pointeur sur l'emplacement du BOB � ses coordonn�es d'arriv�e

	movea.l OFFSET_DRAWBOB_DST(a0),a2
	moveq #0,d0
	move.w OFFSET_DRAWBOB_X(a0),d0
	lsr.w #3,d0
	and.b #$FE,d0
	add.l d0,a2
	move.w OFFSET_DRAWBOB_Y(a0),d0
	move.w OFFSET_DRAWBOB_DSTWIDTH(a0),d1
	lsr.w #3,d1
	mulu OFFSET_DRAWBOB_DEPTH(a0),d1
	mulu d1,d0
	add.l d0,a2

	;Afficher le BOB

	move.w OFFSET_DRAWBOB_X(a0),d0
	and.w #$000F,d0
	ror.w #4,d0
	move.w d0,BLTCON1(a5)		;BSH3-0=d�calage
	or.w #$0FF2,d0
	move.w d0,BLTCON0(a5)		;ASH3-0=d�calage, USEA=1, USEB=1, USEC=1, USED=1, D=A+bC
	move.w OFFSET_DRAWBOB_DX(a0),d0
	addi.w #16,d0
;Si toutes les lignes du masque sont identiques, le masque pourrait �tre une ligne r�p�t�e par le Blitter, plut�t que r�p�t�e dans les donn�es :
;BOBMask:	BLK.W BOB_DX>>4,$F0F0
;			DC.W $0000
;Pour cela, le modulo du masque devrait �tre -((BOB_DX+16)>>3) :
;	move.w d0,d1
;	lsr.w #3,d1
;	neg.w d1
;	move.w d1,BLTBMOD(a5)
	move.w #0,BLTBMOD(a5)
	move.w OFFSET_DRAWBOB_DSTWIDTH(a0),d1
	sub.w d0,d1
	lsr.w #3,d1
	move.w d1,BLTDMOD(a5)
	move.l a1,BLTAPTH(a5)
	move.l OFFSET_DRAWBOB_MASK(a0),BLTBPTH(a5)
	move.l a2,BLTCPTH(a5)
	move.l a2,BLTDPTH(a5)
	move.w OFFSET_DRAWBOB_DY(a0),d1
	mulu OFFSET_DRAWBOB_DEPTH(a0),d1
	lsl.w #6,d1
	lsr.w #4,d0
	or.w d1,d0
	move.w d0,BLTSIZE(a5)

	movem.l (sp)+,d0-d1/a0-a2
	rts

drawBOBData:
OFFSET_DRAWBOB_DEPTH=0
OFFSET_DRAWBOB_X=2
OFFSET_DRAWBOB_Y=4
OFFSET_DRAWBOB_DX=6			;Multiple de 16
OFFSET_DRAWBOB_DY=8
OFFSET_DRAWBOB_MASK=10		;Modulo � 0
OFFSET_DRAWBOB_SRC=14
OFFSET_DRAWBOB_SRCWIDTH=18
OFFSET_DRAWBOB_SRCX=20		;Multiple de 16
OFFSET_DRAWBOB_SRCY=22
OFFSET_DRAWBOB_DST=24
OFFSET_DRAWBOB_DSTWIDTH=28
DATASIZE_DRAWBOB=30
	BLK.B DATASIZE_DRAWBOB,0

;********** Donn�es **********

dmacon:				DC.W 0
intena:				DC.W 0
intreq:				DC.W 0
copperList:			DC.L 0
graphicsLibrary:	DC.B "graphics.library",0
					EVEN
background:			DC.L 0
frontBuffer:		DC.L 0
backBuffer:			DC.L 0
BOB:				BLK.W DISPLAY_DEPTH*BOB_DY*(BOB_DX>>4),0
BOBMask:			REPT DISPLAY_DEPTH*BOB_DY	;Cette r�p�tition peut �tre �vit�e en utilisant un modulo n�gatif (cf. _drawBOB)
					BLK.W BOB_DX>>4,$F0F0
					DC.W $0000
					ENDR
bobX:				DC.W BOB_X
bobY:				DC.W BOB_Y
oldBobX:			DC.W BOB_X
oldBobY:			DC.W BOB_Y
bobSpeedX:			DC.W 1
bobSpeedY:			DC.W 1
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
