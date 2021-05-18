;-------------------------------------------------------------------------------
;                                Temporisations
;
; Codé par Yragael / Denis Duplan (stashofcode@gmail.com) en mai 2018.
;
; Code & documentation on www.stashofcode.com (EN) and www.stashofcode.fr (FR)
;-------------------------------------------------------------------------------

;Cette oeuvre est mise à disposition selon les termes de la Licence (http://creativecommons.org/licenses/by-nc/4.0/) Creative Commons Attribution - Pas d’Utilisation Commerciale 4.0 International.

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
;Utilisation des registres :
;	=D0 *D1 =D2 =D3 =D4 =D5 =D6 =D7 =A0 =A1 =A2 =A3 =A4 =A5 =A6
;Notice :
;	Attention si la boucle d'où provient l'appel prend moins d'une ligne pour s'exécuter, car il faut alors deux appels :
;
;	move.w #Y+1,d0
;	jsr _waitRaster
;	move.w #Y,d0
;	jsr _waitRaster

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

;---------- Attente de N trames ----------

;Entrée(s) :
;	D0 = Nombre de trames à attendre
;Utilisation des registres :
;	*D0 =D1 *D2 =D3 =D4 =D5 =D6 =D7 =A0 =A1 =A2 =A3 =A4 =A5 =A6

_wait:
	movem.l d0-d2,-(sp)
	move.w d0,d2
_waitLoop:
	IFNE DEBUG							;Ne fonctionne que si D0 = 1
	move.w #$0000,BPLCON3(a5)			;Compatibilité AGA : sélectionner la palette 0
	move.w #$00F0,COLOR00(a5)
	ENDC
	move.w #DISPLAY_Y+DISPLAY_DY,d0
	jsr _waitRaster
	IFNE DEBUG							;Ne fonctionne que si D0 = 1
	move.w #$0000,BPLCON3(a5)			;Compatibilité AGA : sélectionner la palette 0
	move.w #$0F00,COLOR00(a5)
	ENDC
	move.w #DISPLAY_Y+DISPLAY_DY+1,d0	;Attention à ce que cela ne dépasse pas 312 !
	jsr _waitRaster
	subq.w #1,d2
	bne _waitLoop
	movem.l (sp)+,d0-d2
	rts
