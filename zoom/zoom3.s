;Codé par Denis Duplan pour Stash of Code (http://www.stashofcode.fr, stashofcode@gmail.com) en 2018.

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

;Zoom hardware horizontal d'une image sur 1 bitplane (suite logique de zoom.s)

;Pour chaque ligne d'une région verticale de ZOOM_DY lignes commençant à la ligne ZOOM_Y, la Copper list contient :

;[0]	WAIT ($00 & $FE, Y & $7F)
;[4]	MOVE BPL1MOD
;[8]	MOVE BPL2MOD
;[12]	MOVE BPLCON1
;[16]	WAIT ($3D & $FE, Y & $7F)
;[20]	40 MOVE dont un certain nombre dans BPLCON1, les autres étant l'équivalent de NOP

;Le principe est de modifier le moins possible la Copper list. A chaque étape du zoom :

;- Seules les instructions MOVE dans BPL1MOD et BPL2MOD des lignes supprimées sont modifiées pour supprimer ces lignes : les valeurs des MOVE x,BPL1MOD et MOVE x,BPL2MOD sont modifiées.

;- Seules les instructions MOVE des colonnes supprimées sont modifiées : un ZOOM_NOP est remplacé par un MOVE x,BPLCON1.

;Un principe gouverne tout zoom : quand l'image est réduite progressivement, un pixel qui a été supprimé ne doit pas réapparaître par la suite. Ce principe peut être facilemet respecté horizontalement, car le zoom hardware repose sur un mécanisme qui suppprime le dernier pixel d'un groupe de 16 pixels indépendamment des autres. Le principe est plus difficile à respecter verticalement, car le zoom hardware repose sur un mécanisme qui supprime une ligne en fonction de celles supprimées avant. Pour le dire autrement, la suppression de colonnes repose sur des références absolues (lorsqu'on doit supprimer N colonnes pour passer d'une étape du zoom à la suivante, on peut désigner chaque colonne indépendamment des autres : zoomer une fois en supprimant N colonnes, cela revient à désigner les colonnes à supprimer dans l'image initiale, puis à les supprimer toutes d'un coup dans cette image), la suppression de lignes repose sur des références relatives (lorsqu'on doit supprimer N lignes pour passer d'une étape du zoom à la suivante, on doit désigner chaque ligne en tenant compte des autres : zoomer une fois en supprimant N lignes, cela revient à désigner une ligne à supprimer dans l'image initiale, supprimer cette dernière, puis désigner la ligne suivante à supprimer dans l'image qui en résulte, etc.)

;Mais toute médaille a son revers, et la facilité offerte par le zoom hardware horizontal sur le zoom hardware vertical a un prix. Autant le zoom hardware vertical permet de supprimer N lignes quelles qu'elles soient, autant le zoom hardware horizontal ne permet de supprimer qu'une colonne toutes les 16 colonnes uniquement, à concurrence de 15 colonnes. On voit le problème : quand la largeur de l'image passe sous 16*15, le nombre de ses colonnes qu'il est possible de supprimer se trouve réduit :

;306          => 306 / 16 = 19 >= 15 => on peut supprimer jusqu'à 15 colonnes
;306-15 = 291 => 291 / 16 = 18 >= 15 => idem
;291-15 = 276 => 276 / 16 = 17 >= 15 => idem
;276-15 = 261 => 261 / 16 = 16 >= 15 => idem
;261-15 = 246 => 246 / 16 = 15 >= 15 => idem
;246-15 = 231 => 231 / 16 = 14 < 15 => on ne peut supprimer que 14 colonnes
;231-14 = 217 => 217 / 16 = 13 < 15 => on ne peut supprimer que 13 colonnes
;...

;Il apparaît ainsi que pour réduire une image de 306 à 15 pixels de large (à partir de quoi il n'est plus possible d'y supprimer une colonne), il faut passer par 46 étapes, chaque étape consistant à procéder à toutes les suppressions de colonnes possibles par zoom hardware puis à actualiser l'image en y supprimant réellement ces colonnes (zoom software), avant de réinitialiser le zoom hardware et de repartir pour un tour avec la nouvelle image. Le mécanisme est décrit dans le fichier Excel.

;La Copper list doit être gérée avec un double-buffer. En effet, les instructions qu'elle contient sont exécutées tout au fil de la trame, si bien que l'intervalle de temps disponible pour la modifier intégralement sans provoquer de flickering serait autrement extrêmement bref : entre la fin de la dernière ligne de l'image, à laquelle le Copper a dû attendre terminer d'exécuter la Copper list en modifiant les valeurs de BPLCON1 le long de la ligne (bref, la ligne suivante DISPLAY_Y + DISPLAY_DY), et la première ligne à partir de laquelle le Copper commence à exécuter la Copper list, c'est-à-dire la ligne 0.

;********** Constantes **********

;Programme

DISPLAY_DEPTH=4
DISPLAY_DX=320
DISPLAY_DY=256
DISPLAY_X=$81
DISPLAY_Y=$2C
PICTURE_DY=256
ZOOM_Y=DISPLAY_Y
ZOOM_X=$3D
ZOOM_DY=DISPLAY_DY
ZOOM_NOP=$01FE0000
COPPERLIST=10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+ZOOM_DY*(5+40)*4+4+4
DEBUG=1

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
	move.l d0,copperListA

	;Allouer de la mémoire en Chip mise à 0 pour la Copper list

	move.l #COPPERLIST,d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,copperListB

	;Allouer de la mémoire en CHIP mise à 0 pour les bitplanes

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,bitplanesA

	;Allouer de la mémoire en CHIP mise à 0 pour les bitplanes

	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	move.l #$10002,d1
	jsr -198(a6)
	move.l d0,bitplanesB

	;Attendre un VERTB (pour éviter que les sprites ne bavent) et couper les interruptions hardware et les DMA

	lea $DFF000,a5
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

	movea.l copperListA,a0

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
	move.w #((DISPLAY_X-17+(((DISPLAY_DX>>4)-1)<<4))>>1)&$00FC,(a0)+	;Ce qui revient ((DISPLAY_X-17+DISPLAY_DX-16)>>1)&$00FC si DISPLAY_DX est multiple de 16
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+
	move.w #FMODE,(a0)+
	move.w #0,(a0)+

	;Adresses des bitplanes

	move.w #BPL1PTH,d0
	move.l bitplanesA,d1
	move.w #DISPLAY_DEPTH-1,d2
_bitplanes:
	move.w d0,(a0)+
	addq.w #2,d0
	swap d1
	move.w d1,(a0)+
	move.w d0,(a0)+
	addq.w #2,d0
	swap d1
	move.w d1,(a0)+	
	addi.l #DISPLAY_DY*(DISPLAY_DX>>3),d1
	dbf d2,_bitplanes

	;Palette

	lea colors,a1
	IFNE DEBUG
	move.l #$01FE0000,(a0)+		;Equivalent de NOP pour neutraliser toute modification de COLOR00 sans modifier la taille de la palette dans la Copper list
	move.w #COLOR01,d1
	lea 2(a1),a1
	moveq #(1<<DISPLAY_DEPTH)-2,d0
	ELSE
	move.w #COLOR00,d1
	moveq #(1<<DISPLAY_DEPTH)-1,d0
	ENDC
_copperListColors:
	move.w d1,(a0)+
	addq.w #2,d1
	move.w (a1)+,(a0)+
	dbf d0,_copperListColors

	;Zoom

	move.w #ZOOM_Y<<8,d0
	move.w #ZOOM_DY-1,d2
_zoomLines:
	move.w d0,d1
	or.w #$00!$0001,d1
	move.w d1,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+
	move.w #BPL1MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPL2MOD,(a0)+
	move.w #0,(a0)+
	move.w #BPLCON1,(a0)+
	move.w #$0007,(a0)+
	move.w d0,d1
	or.w #ZOOM_X!$0001,d1
	move.w d1,(a0)+
	move.w #$8000!($7F<<8)!$FE,(a0)+
	move.w #40-1,d3
_zoomLine:
	move.l #ZOOM_NOP,(a0)+
	dbf d3,_zoomLine
	addi.w #$0100,d0
	dbf d2,_zoomLines
	move.w #BPLCON1,(a0)+
	move.w #$0000,(a0)+
	
	;Fin

	move.l #$FFFFFFFE,(a0)

	;Rétablir les DMA

	move.w #$83C0,DMACON(a5)	;DMAEN=1, BPLEN=1, COPEN=1, BLTEN=1

	;Activer la Copper list

	move.l copperListA,COP1LCH(a5)
	clr.w COPJMP1(a5)

;********** Programme principal **********

	;Copier l'image dans le bitplane 1

	move.w #$05CC,BLTCON0(a5)	;USEA=0, USEB=1, USEC=0, USED=1, D=B
	move.w #$0000,BLTCON1(a5)
	move.w #0,BLTBMOD(a5)
	move.w #0,BLTDMOD(a5)
	move.l #picture,BLTBPTH(a5)
	movea.l bitplanesA,a0
	lea ((DISPLAY_DY-PICTURE_DY)>>1)*(DISPLAY_DX>>3)(a0),a0
	move.l a0,BLTDPTH(a5)
	move.w #(PICTURE_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Recopier la Copper list pour disposer d'une version qu'il est possible de modifier sans impacter l'affichage	

	move.w #(COPPERLIST>>2)-1,d0
	movea.l copperListA,a0
	movea.l copperListB,a1
_copyCopperList:
	move.l (a0)+,(a1)+
	dbf d0,_copyCopperList

;---------- Boucle principale ----------

	lea zoomSteps,a0
	lea zoomColumns,a1
	move.l a1,zoomColumnsB
	clr.b d0
	move.b d0,nbColumnsB

_loop:

	;Attendre la fin de la trame

	move.w d0,d1
	moveq #1,d0
	jsr _wait
	move.w d1,d0

	;Permuter circulairement les Coppper list

	move.l copperListB,d1
	move.l copperListA,copperListB
	move.l d1,copperListA
	move.l copperListA,COP1LCH(a5)

	;Réinitialiser le zoom : effacer les MOVE précédents dans BPLCON1

	movea.l zoomColumnsB,a4
	lea 1(a4),a4
	movea.l copperListB,a2
	lea 10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+5*4(a2),a2
	move.b nbColumnsB,d1
_clearBPLCON1a:
	subq.b #1,d1
	blt _clearBPLCON1Done
	clr.w d2
	move.b (a4)+,d2
	add.w d2,d2
	add.w d2,d2					;D2 = offset du MOVE dans BPLCON1 à remplacer par un NOP à toutes les lignes
	lea (a2,d2.w),a3
	move.w #ZOOM_DY-1,d2
_clearBPLCON1b:
	move.l #ZOOM_NOP,(a3)
	lea (5+40)*4(a3),a3
	dbf d2,_clearBPLCON1b
	bra _clearBPLCON1a
_clearBPLCON1Done:

	;Mémoriser les informations requises pour effacer (à la prochaine trame) les MOVE de la Copper list désormais à l'écran

	move.l a1,zoomColumnsB
	move.b d0,nbColumnsB

	;++++++++++ Réduire l'image s'il n'est plus possible de pousser le zoom hardware ++++++++++

	cmp.b ZOOMSTEP_GROUPS_ZOOMED(a0),d0				;D0 = # de colonnes / lignes qui ont été supprimées à cet instant
	bne _noShrink

	;Quitter si le zoom ne peut être poursuivi

	tst.b ZOOMSTEP_DATASIZE(a0)
	beq _end

	;Effacer l'image

	move.w #$01CC,BLTCON0(a5)			;USEA=0, USEB=1, USEC=0, USED=1, D=B
	move.w #$0000,BLTCON1(a5)
	move.w #$0000,BLTBDAT(a5)
	move.w #0,BLTDMOD(a5)
	move.l bitplanesB,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!(DISPLAY_DX>>4),BLTSIZE(a5)
	WAIT_BLITTER

	;Recopier en les décalant sur la droite les groupes non zoomés à gauche du premier groupe zoomé, ainsi que le premier groupe zoomé après avoir masqué son dernier pixel

	move.w #$0002,BLTCON1(a5)	;DESC=1

	clr.w d0
	move.b ZOOMSTEP_GROUPS_FIRST(a0),d0
	clr.w d1
	move.b ZOOMSTEP_GROUPS_NOTZOOMED_LEFT(a0),d1
	addq.b #2,d1				;Ajouter le premier groupe zoomé ainsi qu'un groupe dans lequel les pixels décalés seront chassés
	add.b d1,d0
	add.b d0,d0
	addi.w #(DISPLAY_DY-1)*(DISPLAY_DX>>3)-4,d0
	movea.l bitplanesA,a2
	lea (a2,d0.w),a2
	move.l a2,BLTAPTH(a5)
	movea.l bitplanesB,a3
	lea 2(a3,d0.w),a3			;Pour produire un décalage à droite en copiant avec décalage à gauche en mode DESC, il faut que la destination se trouve un WORD après la source
	move.l a3,BLTDPTH(a5)
	move.w #DISPLAY_DX>>4,d0
	sub.w d1,d0
	add.w d0,d0
	move.w d0,BLTAMOD(a5)
	move.w d0,BLTDMOD(a5)
	clr.w d0
	move.b ZOOMSTEP_SHIFT(a0),d0
	ror.w #4,d0
	move.w #$09F0,d2
	or.w d0,d2
	move.w d2,BLTCON0(a5)		;ASH3-0=décalage, USEA=1, USEB=0, USEC=0, USED=1, D=A
	move.w #$FFFE,BLTAFWM(a5)
	move.w #$0000,BLTALWM(a5)
	or.w #DISPLAY_DY<<6,d1
	move.w d1,BLTSIZE(a5)
	WAIT_BLITTER

	;Recopier les groupes zoomés en masquant leur dernier pixel en les décalant toujours moins sur la droite (donc en incrémentant le décalage sur la gauche dans BLTCON1)

	move.b ZOOMSTEP_GROUPS_ZOOMED(a0),d1
	move.w #$FFFE,BLTAFWM(a5)
	move.w #(DISPLAY_DX-32)>>3,BLTAMOD(a5)
	move.w #(DISPLAY_DX-32)>>3,BLTCMOD(a5)
	move.w #(DISPLAY_DX-32)>>3,BLTDMOD(a5)
_shrinkColumns:
	subq.b #1,d1
	beq _shrinkDone
	addi.w #$1000,d0			;Quand le décalage atteint 15, il reboucle sur un décalage de 15 comme on le souhaite : $Fxxx + $1000 = $0000
	beq _shrinkKeepDestinationWord			;Il faut gérer le cas délicat où le décalage sur la gauche arrive à saturation, c'est-à-dire quand il doit passer à 16 alors qu'il ne peut dépasser 15 : c'est alors un changement d'adresse et une remise à 0 du décalage
	lea 2(a3),a3
_shrinkKeepDestinationWord:
	lea 2(a2),a2
	move.w d0,d2
	or.w #$0BFA,d2
	move.w d2,BLTCON0(a5)		;ASH3-0=décalage, USEA=1, USEB=0, USEC=1, USED=1, D=A+C
	move.l a2,BLTAPTH(a5)
	move.l a3,BLTCPTH(a5)
	move.l a3,BLTDPTH(a5)
	move.w #(DISPLAY_DY<<6)!2,BLTSIZE(a5)
	WAIT_BLITTER
	bra _shrinkColumns
_shrinkDone:

	;Recopier les colonnes non zoomées qui suivent la dernière colonne zoomée en les décalant sur la droite

	clr.w d1
	move.b ZOOMSTEP_GROUPS_NOTZOOMED_RIGHT(a0),d1
	beq _shrinkRDone
	addi.w #$1000,d0
;faut pas un contrôle de passage de frontière sur A3 comme plus haut ?
	or.w #$0BFA,d0
	move.w d0,BLTCON0(a5)		;ASH3-0=décalage, USEA=1, USEB=0, USEC=1, USED=1, D=A+C
	move.w #$FFFF,BLTAFWM(a5)
	move.w d1,d0
	addq.b #1,d1				;Ajouter un groupe dans lequel les pixels décalés seront chassés
	move.w #DISPLAY_DX>>4,d2
	sub.b d1,d2
	add.w d2,d2
	move.w d2,BLTAMOD(a5)
	move.w d2,BLTCMOD(a5)
	move.w d2,BLTDMOD(a5)
	add.b d0,d0
	lea (a2,d0.w),a2
	move.l a2,BLTAPTH(a5)
	lea (a3,d0.w),a3
	move.l a3,BLTCPTH(a5)
	move.l a3,BLTDPTH(a5)
	or.w #DISPLAY_DY<<6,d1
	move.w d1,BLTSIZE(a5)
	WAIT_BLITTER
_shrinkRDone:

	;Permuter circulairement les bitplanes

	move.l bitplanesB,d0
	move.l bitplanesA,bitplanesB
	move.l d0,bitplanesA

	movea.l copperListB,a2
	movea.l copperListA,a3
	lea 10*4+2(a2),a2
	lea 10*4+2(a3),a3
	move.w #DISPLAY_DEPTH-1,d2
_swapBitplanes:
	swap d0
	move.w d0,(a2)
	move.w d0,(a3)
	swap d0
	move.w d0,4(a2)
	move.w d0,4(a3)
	addi.l #DISPLAY_DY*(DISPLAY_DX>>3),d0
	lea 8(a2),a2
	lea 8(a3),a3
	dbf d2,_swapBitplanes

	;Réinitialiser le zoom : se préparer à ne supprimer que la première colonne d'une nouvelle série de colonnes

	lea ZOOMSTEP_DATASIZE(a0),a0
	lea zoomColumns,a1
	clr.b d0

_noShrink:

	;++++++++++ Appliquer le zoom ++++++++++

	;Animer le zoom

	addq.b #1,d0
	lea 16(a1),a1

	;Modifier la valeur des MOVE BPLCON1 de départ de ligne pour centrer l'image horizontalement

	movea.l a1,a2
	movea.l copperListB,a3
	lea 10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+3*4+2(a3),a3
	clr.w d2
	move.b (a2)+,d2			;D2 = valeur de BPLCON1 initiale
	move.w #ZOOM_DY-1,d3
_setStartingBPLCON1:
	move.w d2,(a3)
	lea (5+40)*4(a3),a3
	dbf d3,_setStartingBPLCON1

	;Ecrire les nouvelles valeur des MOVE et le nouveau MOVE dans BPL1CON pour supprimer la colonne à toutes les lignes

	move.b d0,d3				;D3 = # de colonnes à supprimer
	movea.l copperListB,a3
	lea 10*4+DISPLAY_DEPTH*2*4+(1<<DISPLAY_DEPTH)*4+5*4(a3),a3
_setBPLCON1a:
	subi.w #$0001,d2
	clr.w d4
	move.b (a2)+,d4
	add.w d4,d4
	add.w d4,d4				;D4 = offset du MOVE dans BPLCON1 pour supprimer la colonne
	lea (a3,d4.w),a4
	move.w #ZOOM_DY-1,d4
_setBPLCON1b:
	move.w #BPLCON1,(a4)
	move.w d2,2(a4)
	lea (5+40)*4(a4),a4
	dbf d4,_setBPLCON1b
	subq.b #1,d3
	bne _setBPLCON1a

	btst #6,$BFE001
	bne _loop

_end:

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

	movea.l bitplanesA,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	jsr -210(a6)

	movea.l bitplanesB,a1
	move.l #DISPLAY_DEPTH*DISPLAY_DY*(DISPLAY_DX>>3),d0
	jsr -210(a6)

	movea.l copperListA,a1
	move.l #COPPERLIST,d0
	jsr -210(a6)

	movea.l copperListB,a1
	move.l #COPPERLIST,d0
	jsr -210(a6)

	;Dépiler les registres

	movem.l (sp)+,d0-d7/a0-a6
	rts

;********** Interruptions **********

	INCLUDE "common/registers.s"
	INCLUDE "common/wait.s"

;---------- Gestionnaire d'interruption ----------

_rte:
	rte

;********** Données **********

	SECTION data,DATA_C

graphicsLibrary:	DC.B "graphics.library",0
					EVEN
view:				DC.L 0
graphicsBase:		DC.L 0
vectors:		BLK.L 6
copperListA:	DC.L 0
copperListB:	DC.L 0
dmacon:			DC.W 0
intena:			DC.W 0
intreq:			DC.W 0
colors:
				DC.W $0000	;COLOR00	;Playfield 1 (bitplanes 1, 3 et 5)
				DC.W $0FFF	;COLOR01
				DC.W $0700	;COLOR02
				DC.W $0FFF	;COLOR03
				DC.W $0777	;COLOR04
				DC.W $0FFF	;COLOR05
				DC.W $0777	;COLOR06
				DC.W $0FFF	;COLOR07
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
bitplanesA:		DC.L 0
bitplanesB:		DC.L 0
zoomColumns:
				DC.B $07,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0				;BPLCON1 : $0077 -> $0077 (0 colonnes dissimulées)
				DC.B $08,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0				;BPLCON1 : $0088 -> $0077 (1 colonnes dissimulées)
				DC.B $08,21,23,0,0,0,0,0,0,0,0,0,0,0,0,0			;BPLCON1 : $0088 -> $0066 (2 colonnes dissimulées)
				DC.B $09,19,21,23,0,0,0,0,0,0,0,0,0,0,0,0			;BPLCON1 : $0099 -> $0066 (3 colonnes dissimulées)
				DC.B $09,19,21,23,24,0,0,0,0,0,0,0,0,0,0,0			;BPLCON1 : $0099 -> $0055 (4 colonnes dissimulées)
				DC.B $0A,17,19,21,23,24,0,0,0,0,0,0,0,0,0,0			;BPLCON1 : $00AA -> $0055 (5 colonnes dissimulées)
				DC.B $0A,17,19,21,23,24,25,0,0,0,0,0,0,0,0,0		;BPLCON1 : $00AA -> $0044 (6 colonnes dissimulées)
				DC.B $0B,15,17,19,21,23,24,25,0,0,0,0,0,0,0,0		;BPLCON1 : $00BB -> $0044 (7 colonnes dissimulées)
				DC.B $0B,15,17,19,21,23,24,25,27,0,0,0,0,0,0,0		;BPLCON1 : $00BB -> $0033 (8 colonnes dissimulées)
				DC.B $0C,13,15,17,19,21,23,24,25,27,0,0,0,0,0,0		;BPLCON1 : $00CC -> $0033 (9 colonnes dissimulées)
				DC.B $0C,13,15,17,19,21,23,24,25,27,29,0,0,0,0,0	;BPLCON1 : $00CC -> $0022 (10 colonnes dissimulées)
				DC.B $0D,11,13,15,17,19,21,23,24,25,27,29,0,0,0,0	;BPLCON1 : $00DD -> $0022 (11 colonnes dissimulées)
				DC.B $0D,11,13,15,17,19,21,23,24,25,27,29,31,0,0,0	;BPLCON1 : $00DD -> $0011 (12 colonnes dissimulées)
				DC.B $0E,9,11,13,15,17,19,21,23,24,25,27,29,31,0,0	;BPLCON1 : $00EE -> $0011 (13 colonnes dissimulées)
				DC.B $0E,9,11,13,15,17,19,21,23,24,25,27,29,31,33,0	;BPLCON1 : $00EE -> $0000 (14 colonnes dissimulées)
				DC.B $0F,7,9,11,13,15,17,19,21,23,24,25,27,29,31,33	;BPLCON1 : $00FF -> $0000 (15 colonnes dissimulées)
zoomSteps:		;Pour une image de 306 pixels de large : # de colonnes à supprimer (donc # de groupes zoomés), décalage vers la gauche à appliquer, indice du premier groupe utilisé, # de groupes non zoomés à gauche des groupes zoomés, # de groupes non zoomés à droite des groupes zoomés
ZOOMSTEP_GROUPS_ZOOMED=0
ZOOMSTEP_SHIFT=1
ZOOMSTEP_GROUPS_FIRST=2
ZOOMSTEP_GROUPS_NOTZOOMED_LEFT=3
ZOOMSTEP_GROUPS_NOTZOOMED_RIGHT=4
ZOOMSTEP_DATASIZE=5
				DC.B 15, 8, 0, 2, 3, 15, 8, 0, 1, 3, 15, 8, 1, 1, 2, 15, 8, 1, 0, 2, 15, 8, 2, 0, 1, 14, 9, 2, 0, 1, 14, 9, 2, 0, 1, 13, 9, 3, 0, 1, 12, 10, 3, 0, 1, 11, 10, 4, 0, 1, 11, 10, 4, 0, 0, 10, 11, 4, 0, 1, 9, 11, 5, 0, 1, 9, 11, 5, 0, 1, 8, 12, 5, 0, 1, 7, 12, 6, 0, 1, 7, 12, 6, 0, 1, 7, 12, 6, 0, 1, 7, 12, 6, 0, 1, 5, 13, 7, 0, 1, 5, 13, 7, 0, 1, 5, 13, 7, 0, 1, 5, 13, 7, 0, 1, 5, 13, 7, 0, 1, 4, 14, 8, 0, 1, 4, 14, 8, 0, 1, 4, 14, 8, 0, 0, 3, 14, 8, 0, 1, 3, 14, 8, 0, 1, 3, 14, 8, 0, 1, 3, 14, 8, 0, 1, 3, 14, 8, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 1, 2, 15, 9, 0, 0, 1, 15, 9, 0, 1, 1, 15, 9, 0, 1, 1, 15, 9, 0, 1, 1, 15, 9, 0, 1, 1, 15, 9, 0, 1, 0
				EVEN
picture:		INCBIN "SOURCES:zoom/dragons320(306)x256x1.raw"
zoomColumnsB:	DC.L 0
nbColumnsB:		DC.B 0