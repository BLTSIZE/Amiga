	;Dessiner le BOB de BOB_DX x BOB_DY pixels à base de pixels de (1 << BOB_DEPTH) couleurs successives
;Pas utilisé mais fonctionne
;bob:				BLK.W BOB_DEPTH*BOB_DY*(BOB_DX>>4),0
	
	moveq #0,d2
	lea bob,a0
	moveq #BOB_DY-1,d1
_bobDrawRows:
	moveq #7,d3
	moveq #BOB_DX-1,d0
_bobDrawCols:	
	move.b d2,d4
	movea.l a0,a1
	moveq #BOB_DEPTH-1,d5
_bobDrawBitplanes:
	lsr.b #1,d4
	bcc _bobDrawSkipBitplane
	bset d3,(a1)
_bobDrawSkipBitplane:
	lea BOB_DY*(BOB_DX>>3)(a1),a1
	dbf d5,_bobDrawBitplanes
	subq.b #1,d3
	bge _bobDrawKeepByte
	lea 1(a0),a0
	moveq #7,d3
_bobDrawKeepByte:
	addq.b #1,d2
	dbf d0,_bobDrawCols
	dbf d1,_bobDrawRows



















SQUARE_DY=16
SQUARE_DX=20

	moveq #0,d0
	move.l #(SQUARE_DX<<16)!SQUARE_DY,d1
	move.q #0,d2
	move.l #((DISPLAY_Y*(DISPLAY_DX>>3))<<16)!(DISPLAY_DX>>3),d3
	move.l #DISPLAY_DEPTH,d4
	movea.l bitplanes,a0
	move.w #(DISPLAY_DY/SQUARE_DY)-1,d5
_checkerDrawRows:
	and.l #$0000FFFF,d0
	move.w #(DISPLAY_DX/SQUARE_DX)-1,d6
_checkerDrawColumns:
	bsr _drawSquare
	addi.l #SQUARE_DX<<16,d0
	dbf d6,_checkerDrawColumns
	addi.w #SQUARE_DY,d0
	addq.b #1,d2
	dbf d5,_checkerDrawRows





;---------- Dessin d'un rectangle (sans clipping) ----------

;Entrée(s) :
;	A0 = Adresse du bitplane
;	D0 = Abscisse du rectangle : Ordonnée du rectangle
;	D1 = Largeur du rectangle (pixels) : Hauteur du rectangle (pixels)
;	D2 = Indice de la couleur du rectangle
;	D3 = Offset entre deux bitplanes (octets) : Largeur d'un bitplane (octets)
;	D4 = Nombre de bitplanes
;Sortie(s) :
;	(aucune)

_drawSquare:
	movem.l d0-d7/a0-a6,-(sp)

	move.w d0,d5
	mulu d3,d5
	swap d0
	move.w d0,d6
	lsr.w #3,d6
	add.w d3,d5
	lea (a0,d5.w),a0
	and.b #$07,d0

_drawSquareBitplanes:
	lsr.b #1,d2
	bcc _drawSquareSkipBitplane

	movea.l a0,a1
	move.w d1,d5
	swap d1
_drawSquareRows:

	movea.l a1,a2
	move.w d1,d6

_drawSquareCols:

	move.b #$FF,d7
	lsr.b d0,d7
	or.b d7,(a2)+
	

	move.b #$FF,d7
	or.b d7,(a2)+
dessiner d6 pixels à partir du pixel d0 en a2
registre dispos : d7!

	subq.w #1,d6
	bne _drawSquareCols

	lea (a1,d3.w),a1
	subq.w #1,d5
	bne _drawSquareRows

_drawSquareSkipBitplane:
	swap d3
	lea (a0,d3.w),a0
	swap d3
	subq.b #1,d4
	bne _drawSquareBitplanes

	movem.l (sp)+,d0-d7/a0-a6
	rts

	
