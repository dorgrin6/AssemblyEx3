INCLUDE Irvine32.inc
INCLUDE ex3_data.inc
.data
	SLIDE = 'S'
	ELEVATE = 'E'
	MOVES_END = ';'
	
	moves BYTE LENGTHOF board DUP(1)
	easyBoard BYTE (LENGTHOF board) DUP(?) ; board after arranging the squares
	evenFlag BYTE 0 ; 0 if current line is even, 1 if odd
	minScore DWORD 
	TAB_KEY = 9 ; tab key sign
	;boardLength BYTE ?
	
	
; Fail reasons
	S_FAIL = 1
	E_FAIL = 2
	MOVES_END_AFTER_BOARD_FAIL = 3
	MOVES_END_BEFORE_BOARD_FAIL = 4
	
.code
myMain PROC
	; make board easier
	mov ebx, OFFSET board
	mov esi, OFFSET easyBoard
	mov edx, LENGTHOF board
	call copyBoardInReverse
	call reverseOddLines
	
	; check board
	push DWORD PTR numcols
	push DWORD PTR numrows
	push OFFSET easyBoard
	call checkboard
	
	cmp eax, 1
	je done ; board isn't valid
	
	push DWORD PTR numcols
	push DWORD PTR numrows
	push OFFSET easyBoard
	push DWORD PTR nomoves
	push OFFSET moveseries
	call findshortseries
	
done:
	exit
myMain ENDP

findshortseries PROC
;---------------------------
;	Finds shortest series of moves that can be played.
;	Recieves: Moves address, maximum size of moves,
;		board address, rows num, cols num.
;	Returns: writes shortest series to moves address.
;		returns 0 if one was found,  1 otherwise
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	push ecx
	push esi
	
	; get next available moves set
	push DWORD PTR nomoves
	push offset moves
	call nextmove
	
	mov esp, ebp
	pop ebp
	ret 20
findshortseries ENDP

gameRun PROC
;---------------------------
; Actual gameplay and moves handler.
; Recieves:
;			- easyBoard current square in EBX
;			- easyBoard offset in ESI
;			- easyBoard length in EDX
;			- moves in ECX
;---------------------------
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi
	
	mov ecx, OFFSET moves
	mov ebx, OFFSET easyBoard
	jmp takeMove
	
checkSquare:
	mov eax, 0
	mov al, [ebx] ; get current square
	cmp al, ELEVATE ; check if E
	je E
	cmp al, SLIDE ; check if S
	je S 
	;else current square is a number
	add score, eax ; add number to score
	jmp takeMove ; go to take next move
	

EandScalc:
	; Preforms this calculation: 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	mov edi, esi ; EDI holds beginingOFFSET
	mov eax, 0
	mov eax, ebx ; EAX holds currentOFFSET
	sub eax, edi
	div numcols ; AH is holding the reminder of (currentOFFSET-beginingOFFSET)%numcols
	add ah, ah
	inc ah	; AH is holding 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	ret
	
E:
	; we need to preform this calculation to find next square of E:
	; INCREASE = 2*numcols-2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	call EandScalc
	
	movzx edi, ah ; EDI is holding 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	mov eax, 0
	add al, numcols ; al=numcols
	add al, numcols ; al=2*numcols
	sub eax, edi ; EAX is now holding INCREASE = 2*numcols-2*[(currentOFFSET-beginingOFFSET)%numcols]+1

	add ebx, eax ; EBX, which is in charge of the currentOFFSET, needs to be increased by INCREASE
	
	mov eax, esi
	add eax, edx
	dec eax
	cmp ebx, eax ; if currentOFFSET is less or equal than the end of the board
	jle checkSquare
	; else - Fail number 2
	mov score, E_FAIL
	jmp Fail
	
S:
	; we need to preform this calculation to find next square of S:
	; DECREASE = 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	call EandScalc

	movzx edi, ah ; EDI is holding DECREASE = 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	sub ebx,edi ; EBX, which is in charge of the currentOFFSET, needs to be decreased by DECREASE	
	
	mov eax, esi
	cmp ebx, eax ; if currentOFFSET is greater or equal than the begining of the board
	jge checkSquare
	; else - Fail number 1
	mov score, S_FAIL
	jmp Fail
	
takeMove:
	mov eax, 0
	mov al, [ecx]
	cmp al, MOVES_END ; should we end moves?
	je checkIfEndBoard	
	jmp checkIfAfterEndBoard
	
checkIfEndBoard:
	; check if we are on the last square in board
	mov eax, esi
	add eax, edx
	dec eax
	cmp ebx,eax ; if currentOFFSET is equal to the end of board
	je Win
	; else- we have reached to the end of the moves, but we didnt reach to the end of board, Fail number 4
	mov score, MOVES_END_BEFORE_BOARD_FAIL
	jmp Fail
	
checkIfAfterEndBoard:
	; check if we passed the end of the board
	add ebx, eax
	mov eax, esi
	add eax, edx
	dec eax
	inc movenum
	inc ecx
	cmp ebx, eax ; if currentOFFSET is less or equal to the end of board
	jle checkSquare
	; else - currentOFFSET is greater than end of board, Fail number 3
	mov score, MOVES_END_AFTER_BOARD_FAIL
	jmp Fail

Fail:
	call printResults
	jmp EndFunc
	
Win:
	inc gamefin
	call printResults
	
EndFunc:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
gameRun ENDP

nextmove PROC
;---------------------------
;	Returns the next move series
;	Recieves: moves array address, moves array size stack respectively.
;	Returns: 1 if all moves covered (66...6), 0 otherwise in EAX
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	push ecx
	push esi
	movesAddress = 8
	movesSize = movesAddress + 4
	result = movesSize + 4
	ALL_COVERED = 1
	NOT_COVERED = 0
	CURRENT_COVERED = 6
	
	sub esp, TYPE BYTE
	mov BYTE PTR [ebp + result], ALL_COVERED
	
	mov esi, [ebp + movesAddress] ; esi = movesAddress
	movzx ebx, BYTE PTR [esi]
	mov ecx, [ebp + movesSize] ; ecx = movesSize
stillCovered:
	cmp BYTE PTR [esi], CURRENT_COVERED
	je continue
	; found a free cell
	mov BYTE PTR [ebp + result], NOT_COVERED
	inc BYTE PTR [esi] ; add one to move
	jmp done
continue:
	inc esi
	loop stillCovered

done:
	mov eax, [ebp + result]
	pop esi
	pop ecx
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret 12 
nextmove ENDP

getBoardLength PROC
;---------------------------
;	Returns board length.
;	Recieves: board address, rows amount, cols amount in stack respectively.
;	Returns: boardLength in EAX
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	boardAddress = 8
	rowsAmount = boardAddress + 4
	colsAmount = rowsAmount + 4
	
	mov eax, DWORD PTR [ebp + rowsAmount]
	mul DWORD PTR [ebp + colsAmount]
	
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret 12
getBoardLength ENDP

checkboard PROC
;---------------------------
;	Checks that board is valid.
;	Recieves: board address, rows amount, cols amount in stack respectively.
;	Returns: 0 in EAX if board is valid, 1 otherwise
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	push ebx
	push ecx
	push edx
	push esi
	boardAddress = 8
	rowsAmount = boardAddress + 4
	colsAmount = rowsAmount + 4
	result = colsAmount + 4
	boardLength = result + 4
	maxNum = 40
	minNum = 1
	INVALID_VAL = 1
	VALID_VAL = 0
	
	sub esp, TYPE BYTE ; boolean value
	mov BYTE PTR [ebp + result], VALID_VAL ; result = 0 (true)
	
	; -- get BoardLength -- 
	sub esp, TYPE DWORD ; eax = boardLength
	mov eax, [ebp + rowsAmount]
	mul DWORD PTR [ebp + colsAmount]
	mov DWORD PTR [ebp + boardLength], eax
	
	mov ecx, DWORD PTR [ebp + boardLength] ; ecx = boardLength
	mov esi, DWORD PTR [ebp + boardAddress] ; eax has board first cell
	; loop through array and check for valid value
again:
	movzx ebx, BYTE PTR [esi]
	cmp BYTE PTR [esi], minNum ; num < minNum
	jb invalid
	cmp BYTE PTR [esi], maxNum ; num > maxNum 
	jbe ok ; minNum <= num <= maxNum
	cmp BYTE PTR [esi], ELEVATE ; num = 'E'
	je isE
	cmp BYTE PTR [esi], SLIDE
	je ok
	
	jmp invalid; num > 40 AND num != 'E' AND num != 'S'
isE: 
	; check not first row
	push DWORD PTR [ebp + colsAmount]
	push esi
	push DWORD PTR [ebp + boardAddress]
	call getNextLineOffset
	mov edx, esi ; current offset
	sub edx, eax ; check if in first line
	cmp edx, DWORD PTR [ebp + boardAddress]
	jae ok	; is in last row
	mov edx, esi
	add edx, eax
	cmp BYTE PTR [edx], SLIDE ; is 'S' ?
	jne ok
invalid:
	mov DWORD PTR [ebp + result], INVALID_VAL ; fail
	jmp done
ok:
	add esi, TYPE BYTE
	loop again
	
done:
	mov eax, [ebp + result]
	; standard epilogue
	pop esi
	pop edx
	pop ecx
	pop ebx
	mov esp, ebp
	pop ebp
	ret 16
checkboard ENDP

getNextLineOffset PROC
;---------------------------
;	Returns the next line offset for S or E.
;	Recieves: board address, current position, num cols in stack.
;	Returns: next line offset in ah
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	push ebx
	push edx ; edx changed div result
	push edi
	
	boardAddress = 8
	currentOFFSET = boardAddress + 4
	colsAmount = currentOFFSET + 4
	
	; Preforms this calculation: 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	mov edi, DWORD PTR [ebp + boardAddress] ; EDI holds beginingOFFSET
	mov eax, DWORD PTR [ebp + currentOFFSET] ; EAX holds currentOFFSET
	sub eax, edi
	mov ebx, DWORD PTR [ebp + colsAmount] ; ebx = num cols
	div numcols ; AH is holding the reminder of (currentOFFSET-beginingOFFSET)%numcols
	add ah, ah
	inc ah	; AH is holding 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	movzx edi, ah
	mov eax, DWORD PTR [ebp + colsAmount] ; eax = colsAmount
	sal eax, 1 ; eax = 2 * colsAmount
	sub eax, edi ; eax = 2colsAmount - 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	
	pop edi
	pop edx
	pop ebx
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret 8
getNextLineOffset ENDP

getPrevLineOffset PROC
;---------------------------
;	Returns the previous line offset for S or E.
;	Recieves: board address, current position, num cols in stack.
;	Returns: next line offset in ah
;---------------------------
	; prologue
	push ebp
	mov ebp, esp
	push ebx
	push edx ; edx changed div result
	push edi
	
	boardAddress = 8
	currentOFFSET = boardAddress + 4
	colsAmount = currentOFFSET + 4
	
	; Preforms this calculation: 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	mov edi, [ebp + boardAddress] ; EDI holds beginingOFFSET
	mov eax, [ebp + currentOFFSET] ; EAX holds currentOFFSET
	sub eax, edi
	mov ebx, [ebp + colsAmount] ; ebx = num cols
	div ebx ; AH is holding the reminder of (currentOFFSET-beginingOFFSET)%numcols
	add ah, ah
	inc ah	; AH is holding 2*[(currentOFFSET-beginingOFFSET)%numcols]+1
	
	pop edi
	pop edx
	pop ebx
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret 8
getPrevLineOffset ENDP

copyBoardInReverse PROC
;---------------------------
; Copies all lines of board to easyboard, and switches them over.
; when easyBoard[i] = board[numrows - i].
;---------------------------
	; standard prolgue
	push ebp
	mov ebp, esp
	; save registers
	push eax
	push ebx
	push ecx
	push edx
	push esi
	
	add ebx, edx ; esi = last place of board

	movzx edx, numcols 
	sub ebx, edx ; esi = first place in last line of board
	
	; set outer loop index
	movzx ecx, numrows 
copyRows:
	push ecx ; save ecx
	mov ecx, edx ; copy number of cols
	; copy column by column
	copyCols:
		mov al, BYTE PTR [ebx] ; copy byte from board
		mov [esi], al ; move to easyBoard 
		; move in arrays
		inc ebx 
		inc esi
		loop copyCols	
		
	pop ecx ; restore ecx
	; reduce esi to previous line
	sub ebx, edx
	sub ebx, edx
	loop copyRows
	
	; restore registers
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret
copyBoardInReverse ENDP

reverseOddLines PROC
;---------------------------
; Reverses all odd numbered array lines of board inplace.
;---------------------------
	; standard prolgue
	push ebp
	mov ebp, esp
	
	; save registers
	push esi
	push ebx
	push ecx
	
	; set loop
	mov evenFlag, 0
	movzx ebx, numcols
	movzx ecx, numrows
	
reverseLoop:
	cmp evenFlag, 0
	je skip ; reverse only odd numbered lines
	call reverseArrayLine
skip:
	add esi, ebx
	not evenFlag
	loop reverseLoop
	
	; restore registers
	pop ecx
	pop ebx
	pop esi
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret
reverseOddLines ENDP

printBoard PROC
;---------------------------
; Prints board.
; Recieves: - board address in esi
;---------------------------
	; standard prolgue
	push ebp
	mov ebp, esp
	
	; backup registers
	push ecx
	push esi
	
	; set for loop
	movzx ecx, numrows
	
	; print line by line
printLoop:
	call printBoardLine
	call CRLF
	loop printLoop
	
	; restore registers
	pop esi
	pop ecx
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret
printBoard ENDP

reverseArrayLine PROC
;---------------------------
; Reverses an array line inplace.
; Recieves: - Line address in ESI
;			- Length of line in numcols
;---------------------------
	; standard prolgue
	push ebp
	mov ebp, esp
	
	; save registers
	push ebx
	push esi
	push ecx
	; push array line to stack
	movzx ecx, numcols
pushLoop:
	movzx bx, BYTE PTR [esi]
	push bx
	inc esi
	loop pushloop
	
	; pop array line back in reverse 
	movzx ecx, numcols 
	sub esi, ecx
popLoop:
	pop bx
	mov [esi],bl
	inc esi
	loop popLoop
	
	; recover registers
	pop ecx
	pop esi
	pop ebx
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret
reverseArrayLine ENDP

printBoardLine PROC
;---------------------------
; Prints a board line.
; Assumes board is a byte array.
; Recieves: - Line address in ESI
;			- Length of line in numcols
;---------------------------
	; standard prolgue
	push ebp
	mov ebp, esp
	
	; save eax
	push eax
	push ecx
	; set for loop
	movzx ecx, numcols
	
printLoop:
	movzx eax, BYTE PTR [esi]
	inc esi
	call writeDec
	mov al, TAB_KEY
	call writeChar
	loop printLoop
	
	; recover eax
	pop ecx
	pop eax
	; standard epilogue
	mov esp, ebp
	pop ebp
	ret
printBoardLine ENDP 
END myMain