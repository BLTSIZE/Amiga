;A FAIRE : Refactorer pour nommer les labels et les variables avec un préfixe. Par ailleurs ce serait mieux que ces routines utilisent de structures de données ques des registres

;---------- Affichage du nombre de lignes écoulées depuis DISPLAY_Y+DISPLAY_DY ----------

;Entrée(s) :
;	A0 = Adresse dans le bitplane
;Utilisation des registres :
;	*D0 =D1 =D2 =D3 =D4 =D5 =D6 =D7 *A0 =A1 =A2 =A3 =A4 =A5 *A6

_showTime:
	movem.l d0/a0,-(sp)
	clr.w d0
	move.l VPOSR(a5),d0
	lsr.l #8,d0
	and.w #$01FF,d0
	cmpi.w #DISPLAY_Y+DISPLAY_DY,d0
	bge _showTimeBelowBitplanes
	;on est passé en haut de l'écran
	addi.w #1+312-(DISPLAY_Y+DISPLAY_DY-1),d0	;312 est la ligne la plus basse que peut trace le faisceau d'électrons
	bra _showTimeDisplayCounter
_showTimeBelowBitplanes:
	;on est toujours en bas de l'écran
	sub.w #DISPLAY_Y+DISPLAY_DY-1,d0
_showTimeDisplayCounter:
	jsr _print4Digits
	movem.l (sp)+,d0/a0
	rts

;---------- Affichage d'un nombre décimal sur 4 chiffres (ie : de 0 à 9999) ----------

;Entrée(s) :
;	A0 = Adresse dans le bitplane
;	D0 = Valeur
;Utilisation des registres :
;	*D0 *D1 *D2 =D3 =D4 =D5 =D6 =D7 *A0 *A1 *A2 *A3 =A4 =A5 *A6

_print4Digits:
	movem.l d0-d2/a0-a3,-(sp)
	and.l #$0000FFFF,d0
	moveq #0,d1
	moveq #3-1,d2
_print4DigitsNumber:
	divu #10,d0		;=> d0=reste:quotient de la division de d0 sur 32 bits
	swap d0
	add.b #$30-$20,d0	;code ASCII de "0" moins l'offset de début dans font ($20)
	move.b d0,d1
	lsl.l #8,d1
	clr.w d0
	swap d0
	dbf d2,_print4DigitsNumber
	divu #10,d0		;=> d0=reste:quotient de la division de d0 sur 32 bits
	swap d0
	add.b #$30-$20,d0	;code ASCII de "0" moins l'offset de début dans font ($20)
	move.b d0,d1
;=> d1 : suite des 4 offset ASCII dans la police des 4 chiffres à afficher, mais en sens inverse (ex: 123 => "3210")
	lea debugFont,a1
	moveq #4-1,d0
_print4DigitsDisplay:
	clr.w d2
	move.b d1,d2
	lsl.w #3,d2
	lea (a1,d2.w),a2
	move.l a0,a3
	moveq #8-1,d2
_print4DigitsDisplayChar:
	move.b (a2)+,(a3)
	lea DISPLAY_DX>>3(a3),a3
	dbf d2,_print4DigitsDisplayChar
	lea 1(a0),a0
	lsr.l #8,d1
	dbf d0,_print4DigitsDisplay
	movem.l (sp)+,d0-d2/a0-a3
	rts

debugFont:
	INCBIN "SOURCES:common/data/fonts/fontWobbly8x8x1.raw"
	EVEN
