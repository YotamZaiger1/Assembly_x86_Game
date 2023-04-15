IDEAL
MODEL small
STACK 100h
DATASEG

; --------------------------
;Your variables here
    ;colors:
    Black         equ 0h
    Blue          equ 1h
    Green         equ 2h
    Cyan          equ 3h
    Red	     	  equ 4h
    Magenta 	  equ 5h
    Brown	      equ 6h
    Light_Gray	  equ 7h
    Dark_Gray	  equ 8h
    Light_Blue	  equ 9h
    Light_Green	  equ 0Ah
    Light_Cyan	  equ 0Bh
    Light_Red	  equ 0Ch
    Light_Magenta equ 0Dh
    Yellow  	  equ 0Eh
    White         equ 0Fh


    ;piles:
    pilePearls db 5d dup(0) ;5 -> max num of piles
    pearls db 0 ;amount of pearls in the game

    ;draw:
    pearlRadius equ 6d ;*has to be less than 16d*
    pearlOnColor equ Light_Cyan
    goButtonOnColor equ White
    exitButtonColor equ Magenta
    levelInfoColor equ Light_Gray
    drawColor db 0h ;see https://stackoverflow.com/questions/22052973/256-color-chart-for-mode-13h
    objX dw 0h     ;screen dimensions = 200x320
    objY dw 0h
    buttonHeight db 0h
    buttonWidth db 0h

    printVarStr db "000" ;used to print numbers on the screen
    printVar db 0

    pearlBetterRadius dw 0 ;used for click check only

    ;math:
    nimResult db 0
    rSeed db 0
    levelSeed db 0

    ;juan:
    juanPile db 0 ;range 0-4
    juanPearls db 0 ;range 1-15
    result db 0
    original db 0

    ;game:
    gameState db 0 ;0: your turn
                ;1: juan's turn
                ;2: none turn
    firstMove db 1 ;used to decide if you can give your turn to juan
    pileChose db 0
    level db 1d
    lost db 0d
    instructionsSTR1 db ' The Pearls Game  -Your task, if you choose to eccept it, is to bit Juan', 13, 10, '+---------------+  at the game of pearls.', 13, 10, 13, 10, ' Instructions:', 13, 10, '     -Your goal is to force Juan to remove the last pearl.', 13, 10, 13, 10, '     -Each turn you can remove as many pearls as you want, BUT from 1 pile only.', 13, 10, '       Notice - Once you remove a pearl from one of the piles you WILL NOT be', 13, 10, '                able to swap a pile until your next turn.', 13, 10, '       BTW: You can remove pearls only from right to left.', 13, 10, 13, 10, '     -When you finish your turn, press the GO button. Then, Juan will play.', 13, 10, 13, 10, '$' ;instructions for the game part 1
    instructionsSTR2 db '     -A fair warning! - Joan is a force to be reckoned with...', 13, 10, 13, 10, 13, 10, '-To view the instructions again press [i].', 13, 10, '-To restart your current level doublePress [i].', 13, 10, 13, 10, '-Press [esc] or click the EXIT button to exit the game.', 13, 10, '-Press [r] to reset your progres.', 13, 10, '-Press [m] to mute/unmute the game.', 13, 10, '-Press any other key to start playing.',13, 10, '$' ;instructions for the game part 2


    ;mouse:
    mouseDown db 0
    clickedOnObject db 0

    ;player data
    fileName db 'p_data.txt', 0

    fileErrorMsg db 'file error: ', '$'
    noFile db 0 ;used to decide to open a new file
    emptyFile db 0 ;used to decide to make new progress

    fileHandle dw 0
    buffer db 9 dup(0)
    openMode db 0 ;0-read 1-write 2-read&write

    varNum db 0h
    varSTR db "000"
    varOffset dw 0

    ;music
    musicFileEnd db 0 ;= 1 if finish reading the whole file.
    sound_byte db 0
    Jfirst db "sound\Jfirst.wav", 0
    laugh1 db "sound\laugh1.wav", 0
    laugh2 db "sound\laugh2.wav", 0
    lose1 db "sound\lose1.wav", 0
    lose2 db "sound\lose2.wav", 0
    lose3 db "sound\lose3.wav", 0
    Premove db "sound\Premove.wav", 0
    start1 db "sound\start1.wav", 0
    win1 db "sound\win1.wav", 0
    win2 db "sound\win2.wav", 0

    musicFileHandle dw ?
    musicOpenErrorCode db 0

    mute db 0 ;1 if true

; --------------------------
CODESEG

;---math---
proc calcNimSum
	;This method calculates the nim sum of the pearls.
	;Nim sum is used to decide the computer move in the game.
	;Input:
	;	pilePearls = list of pearls in each pile.
	;Output:
	; 	nimResult = result
	
	push ax
	push bx
	push cx
	
	xor ax, ax
	
	mov cx, 5h 			    	;5h -> max num of piles, length of pilePearls
	
	mov bx, offset pilePearls   ;preparing for get_value_from_array
		
    nimLoop:
        mov al, [bx]
        xor ah, al
        inc bx
        loop nimLoop

    nimExit:
        mov [nimResult], ah

        pop cx
        pop bx
        pop ax
        ret
endp

proc pRandom
    ;This procedure makes a 8bit pseudo-random number.
    ;When the game starts a random seed is generated using system-time.
    ;This seed used to calculate the random numbers.
    ;
    ;Each time the procedure runs it will do the following actions:
    ;   -calculate (8th bit) xor (6th bit) xor (5th bit) xor (4th bit) = x
    ;   -shift right the seed
    ;   -the leftest bit become x
    ;
    ;| -> |1| -> |2| -> |3| -> |4| -> |5| -> |6| -> |7| -> |8| -> delete
    ;|                          |      |      |             |
    ;|                          |      |      |_____xor_____|
    ;|                          |      |_____xor_____|
    ;|                          |_____xor_____|
    ;|_________________________________|
    ;
    ;We choose those specific bits because they give the most 'random' result.
    ;See https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Some_polynomials_for_maximal_LFSRs
    ;Input:
    ;   [rSeed] -> seed
    ;Output:
    ;   [rSeed] -> random number

    push ax
    push cx
    push dx

    mov al, [rSeed]
    and al, 1h

    mov cx, 3h
    mov dl, 4h
    pRandomLoop:
        mov ah, [rSeed]
        and ah, dl

        cmp ah, 0h
        je pRandom0
        mov ah, 1h
        xor al, ah
    pRandom0:
        shl dl, 1h
        loop pRandomLoop



    cmp al, 0h
    je pRandomAl0
    mov al, 80h                 ;0b10_000_000

    pRandomAl0:
        shr [rSeed], 1h
        or [rSeed], al

        pop dx
        pop cx
        pop ax
        ret
endp

proc juan
    ;This procedure is the mind of Juan (the cpu player).
    ;The procedure checks and finds the best move for juan and draws it on the screen.
    ;If there is no best (or good) move juan will play randomly.
    ;See https://en.wikipedia.org/wiki/Nim#Proof_of_the_winning_formula

    push ax
    push bx
    push cx
    push [objX]
    push [objY]

    ;first we check what is the wanted nimSum:
    ;   every pile with 1- doesn't matter
    ;   every pile except 1 with a pearl - nim=1
    ;   else - num=0

    mov bx, offset pilePearls
    xor ax, ax
    mov cx, 5h                                  ;amount of piles

    juanWantedNim:
        mov al, [bx]
        inc bx
        cmp al, 1h
        jna juanNimNotAbove
        inc ah
    juanNimNotAbove:
        loop juanWantedNim

        cmp ah, 0h                              ;ah = amount of piles with more than 1 pearl
        je juanAll1
        cmp ah, 1h
        je juanNim1
        jmp juanNim0





    juanAll1:
        ;This method removes 1 pearl from a random pile.
        ;The chosen pile doesn't matter because every pile has the same amount of pearls in it.

        call pRandom
        mov ah, 1h
        mov cl, [pearls]
        dec cl
        xor ch, ch
        all1Random:                             ;after this loop ch will be a random number in range 0-4
            mov al, [rSeed]
            and al, ah
            jz all1Random0
            inc ch
        all1Random0:
            shl ah, 1h
            dec cl
            jnz all1Random

        ;choosing th cl'th pile with pearls
        mov bx, offset pilePearls
        xor cl, cl
        inc ch                                  ;now ch in range 1-5
        all1ChoosePile:
            cmp [byte ptr bx], 0h
            je all1PileWith0
            dec ch
            jz all1PileFound
            inc cl
        all1PileWith0:
            inc bx
            jmp all1ChoosePile

        all1PileFound:
            mov [juanPile], cl                  ;cl in range 0-4
            mov [juanPearls], 1h                ;there is 1 pearl in the pile
            jmp juanRemove




    juanNim1:
        ;This method runs when the wining move has nimResult 1.
        ;The method removes pearls from THE pile with more than 1 (only one pile).
        ;The amount of pearls that being removed make sure that Juan will win the game.

        ;check if there are odd or even piles with 1 pearl
        xor cx, cx
        mov bx, offset pilePearls
        juanNim1Loop:
            cmp [byte ptr bx], 0h
            je juanNim1LoopEnd
            cmp [byte ptr bx], 1h
            jne juanNim1LoopBeforeEnd
            xor cl, 1h
            jmp juanNim1LoopEnd

        juanNim1LoopBeforeEnd:
            mov al, ch                              ;al is the pile with more than 1 pearl
        juanNim1LoopEnd:
            inc bx
            inc ch
            cmp ch, 5h
            jne juanNim1Loop

            mov [juanPile], al
            mov bx, offset pilePearls
            xor ah, ah
            add bx, ax                              ;now bx points the pile with more than 1 pearl
            mov ah, [bx]
            mov [juanPearls], ah

            cmp cl, 0h                              ;if there are even number of piles with 1 pearl we remove the whole line
                                                    ;else, we leave there 1
            jne juanNim1End
            dec [juanPearls]
        juanNim1End:
            jmp juanRemove



    juanNim0:
        ;This method runs when there are more than one pile with more than 1 pearl in it.
        ;If Juan is not in a loosing position it will calculate how many pearls to remove and from which pile.
        ;Else, it jumps to juanRandom.

        ;check if juan in a losing position
        call calcNimSum
        cmp [nimResult], 0h
        je juanRandom
        ; call juanMagic ;my algorithm
        call MoveMaker ;Yoavs algorithm
        jmp juanRemove


    juanRandom:
        ;This method runs if Juan is in a loosing position.
        ;It removes a random amount of pearls (1-6) from a random pile.

        ;first we choose a pile
        call pRandom
        mov ah, 1h
        mov cl, 4h
        xor ch, ch

        juanRandomPile:                             ;generate a random number in range 0-4
            mov al, [rSeed]
            and al, ah
            jz juanRandomPile0
            inc ch
        juanRandomPile0:
            shl ah, 1
            dec cl
            jnz juanRandomPile

        ;now we check if the chosen pile has pearls to remove
        mov bx, offset pilePearls
        mov cl, ch
        xor ch, ch
        add bx, cx
        cmp [byte ptr bx], 0h
        je juanRandom                               ;try again

        mov [juanPile], cl

        ;now removing a random number in range 1-6 from the chosen pile
        call pRandom
        mov ah, 1h
        mov cl, 4h                                  ;max num-4
        xor ch, ch

        juanRandomPearls:                           ;generate a random number in range 0-5
            mov al, [rSeed]
            and al, ah
            jz juanRandomPearls0
            inc ch
        juanRandomPearls0:
            shl ah, 1
            dec cl
            jnz juanRandomPearls

        inc ch                                      ;ch in range 1-5
        juanRandomPearlsAbove:
            cmp ch, [byte ptr bx]                   ;bx point the chosen pile
            jna juanGoodRandom
            shr ch, 1h
            jmp juanRandomPearlsAbove

        juanGoodRandom:
            mov [juanPearls], ch
            jmp juanRemove


        juanRemove:
            ;This method is the method that actually removing the pearls from the chosen pile.
            ;(The method updates the needed variables)

            mov [objY], 60d                         ;first pile y
            mov al, [juanPile]
            mov ah, 30d                             ;distance between to vertical pearls
            mul ah
            add [objY], ax                          ;[objY] = first pile y + (distance between to vertical pearls * chosen pile)


            mov [objX], 10d                         ;first column x
            mov bx, offset pilePearls
            mov al, [juanPile]
            xor ah, ah
            add bx, ax

            mov al, [byte ptr bx]
            dec al
            mov ah, 15d                             ;distance between to horizontal pearls
            mul ah
            add [objX], ax                          ;[objX] = first column x + (distance between to horizontal pearls * pearls in pile)


            mov al, [juanPearls]
            sub [byte ptr bx], al                   ;updating [pilePearls]
            sub [pearls], al                        ;updating [pearls]

            xor cl, cl
            mov [drawColor], Black                  ;black color

            
            juanRemovePearls:
                ;pearl removing sound
                push dx
                lea dx, [Premove]
                call musicPlayer
                pop dx

                call drawPearl
                sub [objX], 15d                     ;distance between to horizontal pearls
                inc cl

                cmp cl, [juanPearls]
                jne juanRemovePearls

            juanRemoveEnd:

    mov [gameState], 0h                             ;now it is the player's turn

    pop [objY]
    pop [objX]
    pop cx
    pop bx
    pop ax
    ret
endp

proc juanMagic
    ;This procedure does the magic win of Juan.
    ;It calculates the best move for him - if the procedure runs (even once) juan will win the game!
    ;Output:
    ;   [juanPile] -> chosen pile (range 0-4)
    ;   [juanPearls] -> pearls to remove (range 1-15)
	push ax
	push bx
	push cx
	push dx
	
    call calcNimSum
    mov dl, 8h                      ;1000b every time shift right to get the next bit
    xor cl, cl                      ;counter

    magicLoop:                      ;this loop stops on the first bit (left to right) in [nimResult] that equals 1
        mov dh, [nimResult]
        and dh, dl
        jnz magicRow                ;exit loop
        inc cl

        shr dl, 1h                  ;moving to the next bit
        cmp cl, 5h                  ;avoiding infinit loop (not supposed to happen)
        jne magicLoop


    magicRow:
        push dx                     ;saving the result

        mov ah, 2Ch                 ;get system time for random number genarate
        int 21h				        ;dl = 1/100 sec, dh = sec, cl = min, ch = hour
        xor ah, ah
        mov al, dl
        mov dl, 20d                 ;fifth of 100
        div dl                      ;al = random nuber in range 0-4
        xor ah, ah
        
        pop dx


    mov dh, 5h                      ;used in the following loop
    magicRowLoop:
        div dh                      ;ah in range 0-4 again

        mov al, ah
        mov bx, offset pilePearls

        xor ah, ah
        add bx, ax
        mov ah, [byte ptr bx]       ;ah = amount of pearls in the chosen pile
        and ah, dl                  ;dl is the heighest-1 bit in [nimResult] (magicLoop)
        jnz magicPearls
        inc al
        xor ah, ah
        jmp magicRowLoop
    

    magicPearls:
        mov [juanPile], al          ;chosen pile offset - pilePearls offset

        mov ah, [byte ptr bx]       ;[bx] is the chosen pile
        mov al, ah

        xor ah, [nimResult]         ;* The mathematical algorithm of juan removes (pearlsInPile - (pearlsInPile xor nimResult) ) pearls *
        sub al, ah
        mov [juanPearls], al


    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp

proc MoveMaker
    ;Yoavs algorithm
	push ax
	push bx
	push cx
	push dx
	
	mov bx, offset pilePearls
	mov cl, 5 ;pile index
	
	ForPile:
		mov ch, [bx] ;counter for checking what to sub
		cmp ch, 0
        je ZeroAvoider
		
		WhatToSub:
			mov al, [bx]
			mov [original], al
			sub [bx], ch
			
			push bx
			mov [result], 0
			mov dx, 5
			CalcXor:
				mov bx, offset pilePearls
				add bx, dx
				dec bx
				mov al, [bx]
				xor [result], al ; math--- 
				dec dx
				jnz CalcXor
				
			pop bx
			mov al, [original]
			mov [bx], al
			cmp [result], 0
			je Hitler2 ;return
			
			dec ch
			jnz WhatToSub
		ZeroAvoider:
		inc bx
		dec cl
		jnz ForPile
			
		
	Hitler2:
	mov [juanPearls], ch
	mov al, 5
	sub al,cl
	mov [juanPile], al
	
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp

;---draw---
proc drawPearl
    ;This procedure draws an circle on the screen in specific x, y coordinates.
    ;x and y are the coordinates of the circle center.
    ;pearlRadius is constant and doesn't change during runtime. *NOTICE, pearlRadius has to be LESS than 16d.
    ;This procedure based on the circle formula: x^2 + y^2 = r^2.
    ;Input:
    ;    drawColor -> drawing color
    ;    objX -> x
    ;	 objY -> y
    ;Output:
    ;   circle with radius "pearlRadius" on the screen.

	push bx
	push ax
	push cx
	push dx
	push [objX]
    push [objY]

    mov ax, 02h                 ;hide mouse cursor
	int 33h

    xor bh, bh                  ;initialize bh
    xor dh, dh                  ;initialize dh

    mov al, pearlRadius
    mul al                      ;ah = 0, al = r^2, al^2 < 256

    ;make the circle look nicer
    mov ah, pearlRadius
    add ah, ah
    sub ah, 4h
    jc pearlRadiusDontSub
    jmp pearlRadiusSub


    pearlRadiusDontSub:
        add ah, 4h

    pearlRadiusSub:
        add al, ah

        mov dl, al              ;saving the result in dl, al^2 + ah < 256

        xor cx, cx
        sub cl, pearlRadius
        sub ch, pearlRadius

        jmp pearlLoopX          ;start of i,j loop from -radius to +radius
                                ;cl = i, ch = j

    pearlIncX:
        inc cl

    pearlLoopX:
        cmp cl, pearlRadius     ;checks if end of x loop
        jg pearlEnd

        mov al, cl
        imul al                 ;ax = cl^2
        mov bl, al              ;cl < 16 so cl^2 < 256 and fits in b

        xor ch, ch              ;initialize y_scan
        sub ch, pearlRadius

    pearlLoopY:
        cmp ch, pearlRadius     ;checks if end of y loop
        jg pearlIncX

        mov al, ch
        imul al                 ;ax = ch^2

        add ax, bx              ;ax = ch^2 + cl^
        cmp ax, dx              ;cmp x^2 + y^2, r^2
        jg pearlNextY

        push cx
        push dx
        xor dx, dx
        ;draw pixel
        mov dl, ch
        xor ch, ch

        ;sign extension
        cmp cl, 7fh             ;for x
        jna pearlNotExX
        mov ch, 0ffh            ;if below 0 make sure the all cx is negative

        pearlNotExX:
            cmp dl, 7fh         ;for y
            jna pearlNotExY
            mov dh, 0ffh        ;if below 0 make sure the all dx is negative

        pearlNotExY:

            add cx, [objX]
            add dx, [objY]

            mov ah, 0Ch             ;pixel draw
            mov al, [drawColor]     ;color
            mov bh, 0               ;window
            int 10h

            pop dx
            pop cx

        pearlNextY:
            inc ch

            jmp pearlLoopY


    pearlEnd:

        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop [objY]
        pop [objX]
        pop dx
        pop cx
        pop ax
        pop bx
        ret
endp


proc drawButton
    ;This method draws a button-shape object on the screen.
    ;Input:
    ;   [objX] -> x
    ;   [objY] -> y
    ;   [drawColor] -> color
    ;   [buttonHeight] -> height
    ;   [buttonWidth] -> width

    push ax
    push bx
    push cx
    push dx
    push [objX]
    push [objY]


    mov ah, 0ch                 ;draw pixel mode
    mov al, [drawColor]         ;color
    mov bh, 0h                  ;page
    mov cx, [objX]
    mov dx, [objY]

    xor bl, bl                  ;bl will be the counter
    drawButtonLine:             ;drawing two-height horizontal lines
        int 10h
        inc dx
        int 10h
        dec dx
        inc cx
        inc bl
        cmp bl, [buttonWidth]
        jne drawButtonLine

    mov al, [ButtonHeight]
    xor ah, ah
    add dx, ax

    mov ah, 0ch                 ;draw pixel mode
    mov al, [drawColor]         ;color

    dec dx
    xor bl, bl
    mov cx, [objX]

    drawButtonLine2:            ;drawing two-height horizontal lines
        int 10h
        dec dx
        int 10h
        inc dx
        inc cx
        inc bl
        cmp bl, [buttonWidth]
        jne drawButtonLine2



    mov cx, [objX]
    mov dx, [objY]

    xor bl, bl                  ;bl will be our counter
    drawButtonRow:              ;drawing two-height vertical lines
        int 10h
        dec cx
        int 10h
        inc cx
        inc dx
        inc bl
        cmp bl, [buttonHeight]
        jne drawButtonRow

        mov al, [ButtonWidth]
        xor ah, ah
        add cx, ax

        mov ah, 0ch             ;draw pixel mode
        mov al, [drawColor]     ;color

        dec cx
        xor bl, bl
        mov dx, [objY]

    drawButtonRow2:             ;drawing two-height vertical lines
        int 10h
        inc cx
        int 10h
        dec cx
        inc dx
        inc bl
        cmp bl, [buttonHeight]
        jne drawButtonRow2

    pop [objY]
    pop [objX]
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp

proc drawLevelInfo
    ;This procedure draws the "Level" and the "Lost" preview on the screen.

    push ax
    push bx
    push cx
    push dx
    push es
    push bp
    push [objX]
    push [objY]


    mov ax, 02h                 ;hide mouse cursor
	int 33h

    ;write word "Level"
    mov al, 1
	mov bh, 0
	mov bl, [drawColor]         ;color
	mov cx, 6d                  ;message size
	mov dl, 9d                  ;column
	mov dh, 1                   ;row
	push cs
	pop es
	mov bp, offset LevelInfoText
	mov ah, 13h
	int 10h
	jmp textLevelInfoEnd
	LevelInfoText db "Level:"

    textLevelInfoEnd:
        ;write word "Lost"
        mov al, 1
        mov bh, 0
        mov bl, [drawColor]     ;color
        mov cx, 5d              ;message size
        mov dl, 19d             ;column
        mov dh, 1               ;row
        push cs
        pop es
        mov bp, offset LevelInfoTextLost
        mov ah, 13h
        int 10h
        jmp textLevelInfoLostEnd
        LevelInfoTextLost db "Lost:"

    textLevelInfoLostEnd:
        mov [drawColor], levelInfoColor
        ;draw the level on the screen:
        mov al, [level]
        mov [printVar], al
        mov [objX], 15d
        mov [objY], 1d
        call drawVarNum

        ;draw the number of looses on the screen:
        mov al, [lost]
        mov [printVar], al
        mov [objX], 24d
        mov [objY], 1d
        call drawVarNum


        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop [objY]
        pop [objX]
        pop bp
        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp

proc drawVarNum
    ;This procedure shows the given 3 digit variable on the screen.
    ;Input:
    ;   [printVar] -> variable (max 256)
    ;   [drawColor] -> color
    ;   [objX] -> column
    ;   [objY] -> row

    push ax
    push bx
    push cx
    push dx
    push es
    push bp

    mov ax, 02h             ;hide mouse cursor
	int 33h

    ;calculate the variable correct string value:
    mov bx, offset printVarStr
    add bx, 2d                  ;printVar size is 3 so now bx points the last value

    mov al, [printVar]
    xor ah, ah                  ;now ax = [level]

    mov dl, 10d                 ;get the dozens value of the level
    div dl
    add ah, "0"                 ;get the str value of units digit
    mov [byte ptr bx], ah
    dec bx

    xor ah, ah                  ;now ax = [level]/10
    mov dl, 10d                 ;get the hundreds value of the level
    div dl
    add ah, "0"                 ;get the str value of ah
    mov [byte ptr bx], ah
    dec bx

    add al, "0"                 ;get the str value of al
    mov [byte ptr bx], al

    ;write the level
    mov ax, @data
    mov es, ax
    mov al, 1
    mov bh, 0
    mov bl, [drawColor]         ;color
    mov cx, 3d                  ;message size
    mov dl, [byte ptr objX]     ;column
    mov dh, [byte ptr objY]     ;row
    mov bp, offset printVarStr
    mov ah, 13h
    int 10h

    textLevelNumEnd:
        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop bp
        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp

proc drawExit
    ;This procedure draws the "EXIT" button on the screen.
    ;You can config the color in DataSeg: exitButtonColor

    push ax
    push bx
    push cx
    push dx
    push es
    push bp


    mov ax, 02h                 ;hide mouse cursor
	int 33h

    ;write word "EXIT"
    mov al, 1
	mov bh, 0
	mov bl, exitButtonColor     ;color
	mov cx, 4d                  ;message size
	mov dl, 1d                  ;column
	mov dh, 1                   ;row
	push cs
	pop es
	mov bp, offset exitText
	mov ah, 13h
	int 10h
	jmp textExitEnd
	exitText db "EXIT"

    textExitEnd:
        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop bp
        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp

proc drawGo
    ;This procedure draws the "GO" button on the screen.
    ;The procedure need color input for turning on and off the button.
    ;Input:
    ;   [drawColor] -> color

    push ax
    push bx
    push cx
    push dx
    push es
    push bp
    push [objX]
    push [objY]


    mov ax, 02h                 ;hide mouse cursor
	int 33h

    mov [objX], 257d
    mov [objY], 16d
    mov [buttonWidth], 45d
    mov [buttonHeight], 23d
    call drawButton
    ;write word "go" on the button
    mov al, 1
	mov bh, 0
	mov bl, [drawColor]         ;color
	mov cx, 4d                  ;message size
	mov dl, 33d                 ;column
	mov dh, 3                   ;row
	push cs
	pop es
	mov bp, offset goText
	mov ah, 13h
	int 10h
	jmp textGoEnd
	goText db " GO "

    textGoEnd:
        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop [objY]
        pop [objX]
        pop bp
        pop es
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp

;---mouse---
proc click
    ;This procedure runs when the mouse is clicked. It checks its location and updates all the relevant variables.
    ;Input:
    ;   cx -> mouse x
    ;   dx -> mouse y

    push bx
    push ax


    mov [clickedOnObject], 0h

    ;first, check if the game state is relevant:
    cmp [gameState], 0h
    jne clickEnd

    ;now we check if the mouse has not already pressed
    cmp [mouseDown], 1h
    je clickEnd
    mov [mouseDown], 1h     ;set mouse state to down


    mov ax, 02h             ;hide mouse cursor
	int 33h


    ;check if "go" button has been clicked
    call clickOnGo
    cmp [clickedOnObject], 0h
    jne clickEnd

    ;check if "exit" button has been clicked
    call clickOnExit

    ;check if pearl has been clicked:
    call clickOnPearl

    clickEnd:
        mov ax, 01h             ;show mouse cursor again
        int 33h

        pop ax
        pop bx
        ret
endp


proc clickOnGo
    ;This procedure runs when the "GO" button clicked and does the following things:
    ;                                   +--------------------------------+
    ;                                   |                                |
    ;                                   |                                |
    ;                                   |    mouse in the Button axis?   |
    ;                                   |                                |
    ;                                   |    yes                   no    |        +--------+
    ;                                   +----+----------------------+----+        | ignore |
    ;           +--------------------+       |                      |             +-+---+--+
    ;           | player first move? | <-----+                      |               ^   ^
    ;           |                    |                              |               |   |
    ;           | yes            no  |                              +---------------+   |
    ;           +-+---------------+--+    +-----------------------+                     |
    ;             |               |       | player did something? |                     |
    ;             |               +-----> |                       |                     |
    ;             |                       | yes               no  |                     |
    ;             |                       +--+-----------------+--+                     |
    ;             |                          |                 |                        |
    ;             |    +-----------------+   |                 +------------------------+
    ;             +--> | the player won? |   |
    ;                  | &turn on button | <-+
    ;                  |                 |
    ;                  | yes         no  |
    ;                  +-------------+---+
    ;            +-------+           |
    ;            V                   |  +-----------------------------------+
    ;        +--------------+        +> |updating variables and calling Juan|
    ;        | level = 255? |           +--+--------------------------------+
    ;        |              |              ^      |
    ;        | yes      no  |              |      |      +-----------+
    ;        +-+---------+--+              |      +----> | Juan won? |
    ;          |         |                 |             |           |          +-------------------+
    ;          v         +----+            |             | yes   no  |          |turn off the button|
    ;       +--+--------+     |            |             +--+------+-+          +-----+-------------+
    ;       |jmp endGame|     |            |                |      |                  ^
    ;       +-----------+     |            |                |      +------------------+
    ;                         v            |                V
    ;+------------------------+------------+---+      +----------------------------------------------+
    ;|updating variables and making a new level|      |update variables and make the same level again|
    ;+-----------------------------------------+      +----------------------------------------------+
    ;
    ;Input:
    ;   cx -> mouse x
    ;   dx -> mouse y


    push ax
    push bx
    push cx

    jmp checkOnGo

    clickOnGoNot:
        jmp far clickNotOnGo

    checkOnGo:
        cmp cx, 257d                        ;"go" button start x
        jb clickOnGoNot

        cmp cx, 302d                        ;"go" button start x + width
        ja clickOnGoNot

        cmp dx, 16d                         ;"go" button start y
        jb clickOnGoNot
        cmp dx, 39d                         ;"go" button start y + height
        ja clickOnGoNot

        cmp [firstMove], 1h                 ;check if you can skip your turn
        je clickOnGoFirstMove
        cmp [pileChose], 0h                 ;check if you did something in your turn
        je clickOnGoNot

    clickOnGoFirstMove:
        ;if you got here you clicked the "go" button
        cmp [pileChose], 0                  ;check if you gave juan the first turn
        jne clickOnGoFirstMoveNotPass

        mov [drawColor], Dark_Gray          ;"go" button off color
        call drawGo
        ;juan-starts sound
        push dx
        lea dx, [Jfirst]
        call musicPlayer
        pop dx

    clickOnGoFirstMoveNotPass:
        ;now check if the player won
        cmp [pearls], 1
        jne clickOnGoNotWin

        ;make a new level
        cmp [level], 0ffh
        jne clickOnGoNotMaxLevel
        jmp far endGame

        clickOnGoNotMaxLevel:
            inc [level]
            call makeLevel                  ;we don't need to clean the previous screen- it already has 1 pearl
            call save

            mov [clickedOnObject], 1h
            mov [gameState], 0h             ;now it is the player's turn

            mov [firstMove], 1h             ;now it is the first move of the game
            mov [pileChose], 0h             ;letting the player remove more pearls

            mov [drawColor], goButtonOnColor
            call drawGo

            jmp clickNotOnGo


    clickOnGoNotWin:
        mov [clickedOnObject], 1h
        mov [firstMove], 0h                 ;now it is not the first move of the game
        mov [gameState], 1h                 ;now it is juan's turn
        mov [pileChose], 0h                 ;letting the player remove more pearls

        mov [drawColor], Dark_Gray          ;"go" button off color
        call drawGo
        ;evil lough sound
        push dx
        call randomLaugh
        pop dx


        call juan
        cmp [pearls], 1h
        jne clickNotOnGo
        ;if got here the player lost
        cmp [lost], 0ffh
        je clickOnGoDontIncLost
        ;draw the number of looses on the screen:
        inc [lost]
        mov [drawColor], levelInfoColor
        mov al, [lost]
        mov [printVar], al
        mov [objX], 24d
        mov [objY], 1d
        call drawVarNum
        

        ;loosing sound and delay between lose and new game
        push dx
        call randomLose
        pop dx

        clickOnGoDontIncLost:
            call makeLevel
            mov [firstMove], 1h             ;now it is the first move of the game
            mov [drawColor], goButtonOnColor
            call drawGo
            call save

            ;start sound
            push dx
            lea dx, [start1]
            call musicPlayer
            pop dx

            jmp clickNotOnGo

    clickNotOnGo:
        pop cx
        pop bx
        pop ax
        ret
endp


proc clickOnPearl
    ;This procedure checks if the mouse clicked on a valid pearl.
    ;If it is, the pearl will be deleted and the pilePearls list will be updated.
    ;Notice: when you click a pearl you will need to release the mouse button before
    ;        clicking the next pearl.
    ;If only 1 pearls left the "GO" button will change to "NEXT".
    ;Input:
    ;   cx -> mouse x
    ;   dx -> mouse y
    ;Output:
    ;   [clickedOnObject] -> 1 if the click was on a valid pearl

    push ax
    push bx
    push cx
    push dx
    push [objX]
    push [objY]

    ;first we check if clicked on active pearl
    mov ah, 0dh
    mov bh, 0h
    int 10h                                     ;al = color on specific pixel

    cmp al, pearlOnColor
    je clickOnPearlColor
    jmp far clickNotOnPearl


    clickOnPearlColor:

        mov ah, pearlRadius                     ;initialize the radius
        add ah, ah
        sub ah, 4h
        jc clickPearlRadiusDontSub
        jmp clickPearlRadiusSub

        clickPearlRadiusDontSub:
            add ah, 4h

        clickPearlRadiusSub:
            xor al, al
            add al, ah
            xor ah, ah
            mov [pearlBetterRadius], ax         ;saving the result in [pearlBetterRadius], al^2 + ah < 256


    mov ax, cx
    mov bx, dx

    mov [objX], 10d                             ;first pearl in row x
    mov [objY], 60d                             ;first pearl in column y

    xor cl, cl
    xor dl, dl


    checkMousePearlColumn:
        push ax
        sub ax, [objX]                          ;ax = mouse x - [objX]
        jnc clickNoAbsX
        neg ax                                  ;ax = |mouse x - [objX]|

        clickNoAbsX:
            cmp ax, [pearlBetterRadius]         ;cmp (mouse x - pearlCenter x), radius
            jng checkMousePearlRowFirstTime

            pop ax
            add [objX], 15d                     ;the distance between to horizontal pearls
            inc cl
            cmp cl, 15d                         ;num of columns
            jne checkMousePearlColumn
            jmp far clickNotOnPearl

    checkMousePearlRowFirstTime:
        pop ax

    checkMousePearlRow:
            push bx
            sub bx, [objY]                      ;bx = mouse y - [objY]
            jnc clickNoAbsY
            neg bx                              ;bx = |mouse y - [objY]|

        clickNoAbsY:
            cmp bx, [pearlBetterRadius]         ;cmp (mouse y - pearlCenter y), radius
            jng clickXYInPearlRadius

            pop bx
            add [objY], 30d                     ;the distance between to vertical pearls
            inc dl
            cmp dl, 5d                          ;num of rows
            je clickNotOnPearl
            jmp checkMousePearlRow


    clickXYInPearlRadius:
        pop bx

        ;in this point cl = pearlColumn, dl = pearlRow
        ;we want to check if you can erase the pearl.

        ;check if it is only 1 pearl left, if does you'll can't remove it
        cmp [pearls], 1h
        je clickNotOnPearl


        ;check if the player clicked on the last pearl in the row
        mov bx, offset pilePearls
        add bx, dx

        mov al, [bx]
        sub al, cl

        cmp al, 1h
        jne clickNotOnPearl
        ;only if the second term is also correct do:
        ;dec [byte ptr bx]

        ;now we check if the player didn't choose a pile before
        cmp [pileChose], 0h
        jne clickCheckPile
        mov [pileChose], dl
        add [pileChose], 1h

        mov [drawColor], goButtonOnColor
        call drawGo

        clickCheckPile:
            inc dl
            cmp dl, [pileChose]
            jne clickNotOnPearl

            dec [byte ptr bx]                   ;look at the first term
            dec [pearls]

            mov [drawColor], Black              ;set the color to black
            call drawPearl                      ;and erasing the chosen pearl

            mov [clickedOnObject], 1h           ;set mouse status to clicked

            cmp [pearls], 1h
            jne clickNotOnPearl
            ;winning sound and delay
            push dx
            call randomWin
            pop dx

            call save                           ;saving player data

            ;write word "NEXT" on th "GO" button if AFTER the click 1 pearl left
            mov al, 1
            mov bh, 0
            mov bl, goButtonOnColor ;color
            mov cx, 4d              ;message length
            mov dl, 33d             ;column
            mov dh, 3               ;row
            push cs
            pop es
            mov bp, offset nextText
            mov ah, 13h
            int 10h
            jmp clickNotOnPearl
            nextText db "NEXT"


    clickNotOnPearl:
        pop [objY]
        pop [objX]
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp


proc clickONExit
    ;This procedure exits the game if the exit button has been clicked.
    ;Input:
    ;   cx -> mouse x
    ;   dx -> mouse y
    push ax
    push bx
    push cx

    cmp cx, 7d                                  ;"exit" button start x
    jb clickNotOnExit
    cmp cx, 37d                                 ;"exit" button start x + width
    ja clickNotOnExit

    cmp dx, 7d                                  ;"exit" button start y
    jb clickNotOnExit
    cmp dx, 14d                                 ;"exit" button start y + height
    ja clickNotOnExit

    pop cx
    pop bx
    pop ax
    jmp far endGame

    clickNotOnExit:
        pop cx
        pop bx
        pop ax
        ret
endp

proc instructions
    push ax
    push dx

    mov ax, 03h                         ;new text mode
	int 10h

    mov ah, 9h
    mov dx, offset instructionsSTR1     ;print instructions
    int 21h
    mov dx, offset instructionsSTR2     ;print instructions second part
    int 21h

    mov ah, 1h                          ;wait for key press
    int 21h

    cmp al, 27d                         ;check if [esc] is pressed
    jne instructionsNotExit
    jmp far endGame

    instructionsNotExit:
    cmp al, "r"                         ;check if [r] is pressed
    jne instructionsNotReset
    ;reset progres & save
    call resetProgress
    call save

    instructionsNotReset:
        pop dx
        pop ax
        ret
endp

;---game---
proc startGame
    ;This procedure initializes the game.
    ;After initialization the mainLoop will run the game.

    push ax
    push bx
    push cx
    push dx

    call load

    ;reset variables
    mov [gameState], 0 ;0: your turn, 1: juan's turn, 2: none turn
    mov [firstMove], 1 ;used to decide if you can give your turn to juan
    mov [pileChose], 0

    mov ax, 0013h                    ;change to graphic mode
	int 10h

	mov ah, 0Bh                      ;change background color
	mov bh, 0h
	mov bl, Black                    ;color
	int 10h

	mov ax, 01h                      ;show mouse cursor
	int 33h

    call makeLevel                   ;make the first level of the game

    mov [drawColor], goButtonOnColor ;drawing the "GO" button
    call drawGo

    call drawExit                    ;drawing the "EXIT" button

    mov [drawColor], levelInfoColor  ;drawing the level information display
    call drawLevelInfo

    pop dx
    pop cx
	pop bx
	pop ax
	ret
endp


mainLoop:
    ;This procedure is the main loop of the game.
    ;Before calling this procedure call start_game first (for initialization).

	mov ax, 03h                     ;get mouse input
	int 33h
	shr cx, 1

	and bx, 1                       ;check if the left button is pressed
	jz mouseNotClicked

    call click
    jmp mouseAlreadyUp

    mouseNotClicked:
        ;set mouse down to 0
        cmp [mouseDown], 0h
        je mouseAlreadyUp
        mov [mouseDown], 0h

    mouseAlreadyUp:
        ;get keyboard input
        mov ah, 06h
        mov dl, 0ffh
        int 21h

        ;check if [esc] key is pressed
        cmp al, 27d
        je endGame

        ;check if [m] key is pressed
        cmp al, "m"
        jne mainNotMute

        cmp mute, 0h
        je mainNeedMute
            mov mute, 0h
            jmp mainNotMute

        mainNeedMute:
            mov mute, 1h

        mainNotMute:
        ;check if [i] key is pressed
        cmp al, 105
        jne mainNotInstractions

        call save                   ;save player data
        call instructions
        call startGame

        mainNotInstractions:


	jmp mainLoop


endGame:
    ;End the game and return to text mode.

    call save       ;save player data
	mov ax, 03h     ;return to text mode
	int 10h

	jmp exit


;levels:
proc makeLevel
    ;This procedure makes random piles and draws them on the screen.
    ;The amount of pearls in the piles chosen according to the level:
    ;   -level 1:       2 piles, max 06 pearls in pile.
    ;   -levels 2-5:    3 piles, max 11 pearls in pile.
    ;   -levels 6-15:   4 piles, max 11 pearls in pile.
    ;   -above 15:      5 piles, max 15 pearls in pile.
    ;
    ;Input:
    ;   [level] -> level
    ;Output:
    ;   [pearls] -> amount of pearls in the game
    ;   Updates the level preview on the screen
    ;   [levelSeed] -> the rSeed befor generating the level

    push ax
    push bx
    push cx
    push dx
    push [objX]
    push [objY]

    mov al, [rSeed]
    mov [levelSeed], al           ;saving the level seed

    call resetPilePearls
    mov bx, offset pilePearls

    cmp [level], 1d
    ja lvl2to5

    ;custom level 1:
    call pRandom
    mov al, [rSeed]
    shr al, 6h                    ;get num in range 0-3
    add al, 3d                    ;avoid random < 3
    mov [bx], al


    call pRandom
    mov al, [rSeed]
    shr al, 6h                    ;get num in range 0-3
    add al, 2d                    ;avoid random < 2
    mov ah, al
    shr al, 1h
    add al, ah

    inc bx
    mov [bx], al
    jmp drawLevel

    ;custom levels 2-5:
    lvl2to5:
        cmp [level], 5d
        ja lvl6to15

        call pRandom
        mov al, [rSeed]
        shr al, 6h                ;get num in range 0-3
        add al, 2h                ;avoid random < 2
        mov [bx], al

        mov cx, 2
    lvl2to5Loop:
        call pRandom
        mov al, [rSeed]
        shr al, 5h                ;get num in range 0-7
        add al, 4                 ;avoid random < 4

        inc bx
        mov [bx], al

        loop lvl2to5Loop
        jmp drawLevel


    ;custom levels 6-15:
    lvl6to15:
        cmp [level], 15d
        ja lvl16plus

        call pRandom
        mov al, [rSeed]
        shr al, 5h                ;get num in range 0-7
        add al, 1h                ;avoid random < 1
        mov [bx], al

        mov cx, 3
    lvl6to15Loop:
        call pRandom
        mov al, [rSeed]
        shr al, 5h                ;get num in range 0-7
        add al, 5h                ;avoid random < 4

        inc bx
        mov [bx], al

        loop lvl6to15Loop
        jmp drawLevel


    ;the other levels:
    lvl16plus:
        mov cx, 5
    lvl16plusLoop:
        call pRandom
        mov al, [rSeed]
        shr al, 4h                ;get num in range 0-15
        jnz lvl16NotZero          ;avoid random < 1
        inc al

    lvl16NotZero:
        mov [bx], al
        inc bx

        loop lvl16plusLoop
        jmp drawLevel


    ;drawing the piles
    drawLevel:
        mov [objY], 60d           ;first row y
        mov [objX], 10d           ;first column x
        xor cl, cl
        xor dl, dl
        mov bx, offset pilePearls
        mov [drawColor], pearlOnColor

        drawLevelRow:
            mov al, [bx]
            cmp [byte ptr bx], 0h
            je makeLevelEnd

            call drawPearl
            add [objX], 15d       ;distance between to horizontal pearls
            inc cl

            cmp cl, [bx]
            jne drawLevelRow

            xor cl, cl
            inc bx

            mov [objX], 10d       ;first column x
            add [objY], 30d       ;distance between to vertical pearls
            inc dl
            cmp dl, 5d            ;max amount of rows
            je makeLevelEnd
            jmp drawLevelRow


    makeLevelEnd:
        mov bx, offset pilePearls
        xor al, al
        mov cx, 5
    levelPearlsSumLoop:
        add al, [bx]
        inc bx
        loop levelPearlsSumLoop

        mov [pearls], al

        ;draw the level on the screen
        mov [drawColor], levelInfoColor
        mov al, [level]
        mov [printVar], al
        mov [objX], 15d
        mov [objY], 1d
        call drawVarNum


        pop [objY]
        pop [objX]
        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp

proc resetPilePearls
    ;This procedure resets pilePearls, every pile will be 0 (pearls).
    ;Output:
    ;   [pilePearls] = 0, 0, 0, 0, 0
    
    push cx
    push bx

    mov cx, 5d
    mov bx, offset pilePearls
    resetPileIndex:
        mov [byte ptr bx], 0h
        inc bx
        loop resetPileIndex

    resetPileEnd:
        pop bx
        pop cx
        ret
endp


;save player progress
proc openFile
    ;This procedure opens the player-data file.
    ;If there is no player-data file [noFile] will be set to 1.
    ;Input:
    ;   [openMode] -> 0: read, 1: write, 2: both

    push ax
    push cx
    push dx

    mov ah, 3Dh
    mov al, [openMode]          ;open mode
    lea dx, [fileName]
    int 21h
    jc openError                ;check for errors

    mov [fileHandle], ax        ;set file handle
    jmp openFileNoErrors

    openError:
        cmp al, 2h              ;file not found erro
        jne oppenFileFound
        mov [noFile], 1d
    
    oppenFileFound:
        ;print error message
        mov dx, offset fileErrorMsg
        mov ah, 9h
        int 21h
        mov dl, al              ;print error type
        add dl, "0"
        mov ah, 2
        ; int 21h               ;turn on to print the error


    openFileNoErrors:
        pop dx
        pop cx
        pop ax
        ret
endp openFile


proc closeFile
    ;This procedure coloses the player-data file.

    push ax
    push bx

    mov ah,3Eh
    mov bx, [fileHandle]
    int 21h

    pop bx
    pop ax
    ret
endp closeFile


proc createFile
    push ax
    push cx
    push dx

    mov ah, 3ch                 ;make file
    xor cx, cx                  ;no attributes
    mov dx, offset fileName
    int 21h
    jc createFileError
    mov [fileHandle], ax
    jmp createFileNoErrors
    mov [noFile], 0h

    createFileError:
        ;print error message
        mov dx, offset fileErrorMsg
        mov ah, 9h
        int 21h
        mov ah, 2               ;print error type
        mov dl, al
        int 21h

    createFileNoErrors:
        pop dx
        pop cx
        pop ax
        ret
endp


proc readFile
    ;This procedure reads from the player-data file.
    ;Output:
    ;   [emptyFile] = 1 if the file was empty
    ;   [buffer] -> text in file

    push ax
    push bx
    push cx
    push dx

    mov ah, 3fh                 ;read
    mov bx, [fileHandle]
    mov cx, 9d                  ;num of bytes to read
    mov dx, offset buffer       ;save result in [buffer]
    int 21h

    cmp ax, 0d                  ;check if the file is empty
    jne readFileNotEmpty

    mov [emptyFile], 1h

    readFileNotEmpty:

        pop dx
        pop cx
        pop bx
        pop ax
        ret
endp


proc writeFile
    ;This procedure writes to the player-data file.
    ;Input:
    ;   [buffer] -> str text

    push ax
    push bx
    push cx
    push dx

    mov ah, 40h
    mov bx, [fileHandle]
    mov cx, 9d                  ;str size
    mov dx, offset buffer       ;str to write
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp


proc resetProgress
    ;This procedure resets the player variables.
    call getRandomSeed
    mov [level], 1h
    mov [lost], 0h

    ret
endp



proc getRandomSeed
    ;This procedure gets a random seed.
    ;Output:
    ;   [levelSeed] -> rando number

    push ax
    push cx
    push dx

    mov cx, 1000d                        ;trying to get a random number that does not equal 0, max tries = cx
    getRandomZero:
        push cx
        mov ah, 2Ch                      ;get system time
        int 21h					         ;dl = 1/100 sec, dh = sec, cl = min, ch = hour
        mov [levelSeed], 0
        add [levelSeed], dl
        add [levelSeed], dh
        add [levelSeed], cl
        add [levelSeed], ch

        jnz getRandomSeedEnd
        pop cx
        loop getRandomZero

    getRandomSeedEnd:
        pop cx
        cmp [levelSeed], 0
        jne getRandomNotZero
        mov [levelSeed], 1

    getRandomNotZero:

        pop dx
        pop cx
        pop ax
        ret
endp


proc varNumToSTR
    ;This procedure converts a numeric value to 3 digits str.
    ;Input:
    ;   [varNum] -> numeric number for convert
    ;   [varOffset] -> offset of the var to save the result at
    ;OutPut:
    ;   [givenOffset] -> 3 digits str value of [varNum]

    push ax
    push bx
    push dx

    mov bx, [varOffset]
    add bx, 2h                      ;get to the last object in var

    xor ah, ah
    mov al, [varNum]                ;now ax = [varNum]

    mov dl, 10d
    div dl

    add ah, "0"
    mov [bx], ah                    ;ah = units str value

    xor ah, ah
    div dl

    add ah, "0"                     ;ah = dozens str value
    add al, "0"                     ;al = hundreds str value

    dec bx
    mov [bx], ah
    dec bx
    mov [bx], al

    pop dx
    pop bx
    pop ax
    ret
endp


proc varSTRToNum
    ;This procedure converts a 3 digits str to its numeric value.
    ;Input:
    ;   [varSTR] -> 3 digits str
    ;OutPut:
    ;   [varNum] -> numeric value of [varSTR]
    push ax
    push bx


    mov bx, offset varSTR
    mov [varNum], 0h

    mov ah, 100d
    mov al, [bx]
    sub al, "0"
    mul ah                          ;al = hundreds value
    add [varNum], al

    inc bx
    mov ah, 10d
    mov al, [bx]
    sub al, "0"
    mul ah                          ;al = dozes value
    add [varNum], al

    inc bx
    mov ah, 1d
    mov al, [bx]
    sub al, "0"
    mul ah                          ;al = units value
    add [varNum], al


    pop bx
    pop ax
    ret
endp




proc save
    ;This procedure saves the player progress.

    push ax

    mov [openMode], 1h              ;write mode
    call openFile
    cmp [noFile], 1h
    jne saveFileExist

    call createFile
    call openFile
    call resetProgress

    saveFileExist:
    ;save vars:
    mov al, [level]
    mov [varNum], al
    mov [varOffset], offset buffer
    call varNumToSTR

    mov al, [lost]
    mov [varNum], al
    add [varOffset], 3d             ;next var
    call varNumToSTR

    mov al, [levelSeed]
    mov [varNum], al
    add [varOffset], 3d             ;next var
    call varNumToSTR

    call writeFile


    call closeFile
    pop ax
    ret
endp


proc load
    ;This procedure load the variables from the saved file.
    push ax
    push bx
    push cx

    mov [openMode], 0           ;read mode
    call openFile
    cmp [noFile], 1h
    jne openFileExist

    call createFile
    call openFile

    openFileExist:
        call readFile
        cmp [emptyFile], 1h     ;check if the file is empty
        jne loadFileFull

        call resetProgress
        call closeFile
        call save
        mov [openMode], 0       ;read
        call openFile

    loadFileFull:
    ;load vars
    mov bx, offset buffer
    call loadHelperReadBuffer

    mov bx, offset varSTR
    call loadHelperLoadVar

    call varSTRToNum
    mov al, [varNum]
    mov [level], al


    mov bx, offset buffer
    add bx, 3d                  ;second var
    call loadHelperReadBuffer

    mov bx, offset varSTR
    call loadHelperLoadVar

    call varSTRToNum
    mov al, [varNum]
    mov [lost], al


    mov bx, offset buffer
    add bx, 6d                  ;third var
    call loadHelperReadBuffer

    mov bx, offset varSTR
    call loadHelperLoadVar

    call varSTRToNum
    mov al, [varNum]
    mov [rSeed], al
    mov [levelSeed], al
    


    call closeFile
    pop cx
    pop bx
    pop ax
    ret
endp

proc loadHelperReadBuffer
    mov al, [byte ptr bx]
    inc bx
    mov ah, [byte ptr bx]
    inc bx
    mov cl, [byte ptr bx]
    ret
endp

proc loadHelperLoadVar
    mov [bx], al
    inc bx
    mov [bx], ah
    inc bx
    mov [bx], cl
    ret
endp

;music
proc openMusicFile
    ;This procedure opens the music file.
    ;Output:
    ;   no problems:
    ;       [musicFileHandle] = fileHandle
    ;       [musicOpenErrorCode] = 0
    ;   had problems:
    ;       [musicOpenErrorCode] = error code

    push ax
    push cx
    push dx

    mov [musicOpenErrorCode], 0d

    mov ah, 3Dh
    xor al, al                      ;read mode
    ; lea dx, [musicName]           ;dx = offset music name
    int 21h
    jc musicOpenError               ;check for errors

    mov [musicFileHandle], ax       ;set file handle
    jmp musicOpenFileNoErrors

    musicOpenError:
        mov [musicOpenErrorCode], al
        ;print error message
        mov dl, al                  ;print error type
        add dl, "0"
        mov ah, 2
        int 21h


    musicOpenFileNoErrors:
        pop dx
        pop cx
        pop ax
        ret
endp openMusicFile

proc musicCloseFile
    ;This procedure coloses the music file.

    push ax
    push bx

    mov ah,3Eh
    mov bx, [musicFileHandle]
    int 21h

    pop bx
    pop ax
    ret
endp musicCloseFile


proc readNextSample
    ;This procedure reads from the music file.
    ;Output:
    ;   [sound_byte] = read sound
    ;   [musicFileEnd] = 1 if read the last fish reading the whole file.

    push ax
    push bx
    push cx
    push dx


    mov ah, 3fh                     ;read
    mov bx, [musicFileHandle]
    mov cx, 1                       ;num of bytes to read
    mov dx, offset sound_byte       ;save result in [sound_byte]
    int 21h
    cmp ax, 1                       ;bytes read
    je musicRadNotLats
    mov [musicFileEnd], 1d
    jmp readLastSample

    musicRadNotLats:
    ;set to next file posison
    mov ah, 42h
    mov al, 1                       ;current file position
    xor cx, cx
    mov dx, 1                       ;incrising file position by 1
    int 21h

    readLastSample:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp


proc musicPlayer
    ;This procedure plays music if able to open the music file.

    push ax
    push bx
    push cx
    push dx

    ;check if not muted
    cmp mute, 1h
    je musicPlayError

    call openMusicFile
    cmp [musicOpenErrorCode], 0
    jne musicPlayError


    mov [musicFileEnd], 0

    musicLoop:

        call readNextSample

        ;send DSP Command 10h
        mov bl, 10h
        call sb_write_dsp

        ;send byte audio sample, if muted- send 0
        cmp mute, 1h
        je musicPlayerMute

        mov bl, [sound_byte]
        jmp musicPlayerWriteDsp

        musicPlayerMute:
        xor bl, bl

        musicPlayerWriteDsp:
            call sb_write_dsp

        
        ;check if [m] is clicked
        mov ah, 06h
        mov dl, 0ffh
        int 21h

        cmp al, "m"
        jne musicNotMute

        cmp mute, 0h
        je musicNeedMute
            mov mute, 0h
            jmp musicNotMute

        musicNeedMute:
            mov mute, 1h

        musicNotMute:


        ;delay
        mov cx, 8000d
        delay:
            nop
            loop delay


        cmp [musicFileEnd], 1d
        jne musicLoop



    call musicCloseFile
    musicPlayError:
    
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

endp

proc sb_write_dsp
    mov dx, 22ch
    dspBusy:
        in al, dx
        test al, 10000000b
        jnz dspBusy
    mov al, bl
    out dx, al
    ret
endp


proc randomLaugh
    ;choose a random laugh sound and put its name offset in dx.
    push ax

    call pRandom
    mov al, [rSeed]

    and al, 111b
    ;choose a laugh:
    cmp al, 3
    jnb randomLaughEnd
    
    cmp al, 2
    jnb randomLaugh2

    lea dx, [laugh1]
    jmp randomLaughPlay

    randomLaugh2:
    lea dx, [laugh2]
    jmp randomLaughPlay

    randomLaughPlay:
        call musicPlayer

    randomLaughEnd:
    pop ax
    ret
endp

proc randomLose
    ;choose a random losing sound and put its name offset in dx.
    push ax

    call pRandom
    mov al, [rSeed]

    and al, 11b
    ;choose a lose:
    cmp al, 3
    jne randomLoseNot3

    lea dx, [lose3]
    jmp randomLosePlay

    randomLoseNot3:
    cmp al, 2
    jne randomLoseNot2

    lea dx, [lose2]
    jmp randomLosePlay

    randomLoseNot2:
    lea dx, [lose1]
    jmp randomLosePlay

    randomLosePlay:
        call musicPlayer

    pop ax
    ret
endp

proc randomWin
    ;choose a random winning sound and put its name offset in dx.
    push ax

    lea dx, [win1]

    call pRandom
    mov al, [rSeed]

    and al, 1b
    ;choose a lose:
    jz randomWinPlay
    lea dx, [win2]

    randomWinPlay:
        call musicPlayer

    pop ax
    ret
endp



;-----------------------------------------------
start:
	mov ax, @data
	mov ds, ax

; --------------------------
; Your code here


    call instructions
    call startGame
    jmp mainLoop
	
; ----------------------------------------------
	
exit:
	mov ax, 4c00h
	int 21h
END start

; ****IMPORTANT****
; CHECK FOR:
;       TODO - mute, random sound, logo
;       DELETE
;       