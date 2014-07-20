;   ___    ___    ____   ___    __ __  ____   __  __ ______
;  / _ )  / _ \  / __/  / _ |  / //_/ / __ \ / / / //_  __/
; / _  | / , _/ / _/   / __ | / ,<   / /_/ // /_/ /  / /   
;/____/ /_/|_| /___/  /_/ |_|/_/|_|  \____/ \____/  /_/    
;
;"Breakout" clone for 6502asm.com , the 6502 CPU vm from https://github.com/skilldrick/easy6502
;by Lucas de Almeida a.k.a. drnick
;github: https://github.com/lucasdealmeidasm
;Blog: http://gameprogrammersnotebook.blogspot.com.br/
;
;Thanks to Jedi a.k.a. coderTrevor @ https://github.com/coderTrevor for helping me with some issues during development
;
;"License":
;-Do not misrepresent the authorship of this code
;-Do not remove or modify this header
;
;HOW TO PLAY:
;-Press A to move paddle to the left
;-Press D to move paddle to the right
;-Press any other key to stop the paddle from moving (this is due to the way input is done in easy6502, not my fault)
;-Press P to pause the game

;Address	Variable
;0			ballX
;1			ballY
;2			ballDx, ballDy and ballAngle
;3			pointer for pixelAddress routine, lower byte
;4			pointer for pixelAddress routine, higher byte
;5			frame counter
;6			paddleX
;7			Gameover and victory flags
;8			rngCounter
;9			Pause flag

;SETUP_BLOCKS "routine"
;This is the first part I wrote so the code here is quite different and of lower quality
;please do not mind
SETUP_BLOCKS:
LDY #2
SETUP_BLOCKS_DO_ROW:
TYA
STA $200,X
STA $201,X
STA $202,X
STA $203,X
STA $220,X
STA $221,X
STA $222,X
STA $223,X
INX
INX
INX
INX
INY
TYA
AND #14
CMP #0
BNE SETUP_BLOCKS_SKIPPED_BW
INY
INY
SETUP_BLOCKS_SKIPPED_BW:
TXA
AND #32
CMP #32
BEQ SETUP_BLOCKS_NEXT_ROW
JMP SETUP_BLOCKS_DO_ROW
SETUP_BLOCKS_NEXT_ROW:
TXA
CLC
ADC #32
TAX
BEQ SETUP_BLOCKS_END
JMP SETUP_BLOCKS_DO_ROW
SETUP_BLOCKS_END:

LDY #16
LDX #16
STX 0	;ballX = 16;
STY 1	;ballY = 16;
LDA #12
STA 2	;ballAngle = 3; ballDx = 0; ballDy = 0;
STA 6	;paddleX = 12;
LDA #0
STA 7	;gameOver = false; victory = false;
STA 9	;paused = false;

GAMELOOP:
LDA #255			; Change this value if the game is too slow or too fast
WAIT:				; Slow down so it isn't unplayable
SEC
SBC #1
BCS WAIT
JSR CHECKBLOCKS		; Calls victory checker
LDA 7
CMP #1				; Checks failure flag
BEQ GAMEOVER
CMP #2				; Checks victory flag
BEQ VICTORY
LDA $FF
CMP #$70			; Check if P is pressed, and if it is, change the paused flag
BNE DONOTCHANGEPAUSE
LDA #0
STA $FF				; Overwrite the readkey byte
LDA 9
EOR #1
STA 9
DONOTCHANGEPAUSE:
LDA 9
CMP #1				; Check paused flag
BEQ GAMELOOP
INC 8
INC 8				; Increase RNG counter
INC 5				; Increase frame counter
JSR UPDATEPADDLE	; Updates the paddle (both movement and graphics)
JSR PIXELADDRESS
LDX #0
LDA #0
STA ($3,X)			; Clean ball
LDA 2
AND #4
LSR
LSR
AND 5
CMP #1				; Check angle (see RANDOMANGLE for explanation)
BEQ HORIZONTAL
LDA 2
AND #1
CMP #1				; Check DY
BEQ POSITIVE_DY
JSR MOVEBALLUP
JMP HORIZONTAL
POSITIVE_DY:
JSR MOVEBALLDOWN
HORIZONTAL:
LDA 2
AND #8
LSR
LSR
LSR
AND 5
CMP #1				; Check angle again
BEQ DRAWBALL
LDA 2
AND #2
CMP #2				; Check DX
BEQ POSITIVE_DX
JSR MOVEBALLLEFT
JMP DRAWBALL
JMP GAMELOOP
POSITIVE_DX:
JSR MOVEBALLRIGHT
DRAWBALL:
JSR PIXELADDRESS
LDX #0
LDA #1
STA ($3,X)			; Draw ball
JMP GAMELOOP
GAMEOVER:
VICTORY:
JMP END				; Branches have a reach limit, jumps don't

;PIXELADDRESS routine
;Equivalent C:
;pointer = (((y & 7) << 5) + x) & ((((y >> 3) + 2) & 3) << 8); // Equivalent to (x + (y % 8) * 32) + ((y / 8) + 2) << 8;
PIXELADDRESS:
LDA 1
AND #7
ASL
ASL
ASL
ASL
ASL
CLC
ADC 0
STA 3
LDA 1
LSR
LSR
LSR
AND #3
CLC
ADC #2
STA 4
RTS

;CLEARBLOCK routine
;Equivalent C:
;offset = (x - (x % 4)) + (y - (y % 2)) * 32;
;*((byte *)(offset)) = 0;
;*((byte *)(offset + 1)) = 0;
;*((byte *)(offset + 2)) = 0;
;*((byte *)(offset + 3)) = 0;
;*((byte *)(offset + 32)) = 0;
;*((byte *)(offset + 33)) = 0;
;*((byte *)(offset + 34)) = 0;
;*((byte *)(offset + 35)) = 0;
CLEARBLOCK:
LDA 1
AND #6
ASL
ASL
ASL
ASL
ASL
CLC
ADC 0
AND #252
TAX
LDA #0
STA $200,X
STA $201,X
STA $202,X
STA $203,X
STA $220,X
STA $221,X
STA $222,X
STA $223,X
RTS

;MOVEBALLUP routine
;Equivalent C:
;y--;
;if(y < 0) goto collision;
;if(y >= 8) return;
;if(*(PixelAddress()) == 0) return;
;else
;{
;clearBlock();
;goto collision;
;}
;collision:
;dy != dy;
;y++;
MOVEBALLUP:
LDA 1
SEC
SBC #1
STA 1
BCC MOVEBALLUP_COLLISION
CMP #8
BCS MOVEBALLUP_END
JSR PIXELADDRESS
LDX #0
LDA ($3,X)
CMP #0
BEQ MOVEBALLUP_END
JSR CLEARBLOCK
MOVEBALLUP_COLLISION:
LDA 2
EOR #1
STA 2
INC 1
MOVEBALLUP_END:
RTS

;MOVEBALLDOWN routine
;Equivalent C:
;y++;
;if(y == 31)
;{
;if(x < paddleX) goto gameOver;
;if(x >= paddleX + 8) goto gameOver;
;randomAngle();
;goto collision;
;}
;if(y >= 8) return;
;if(*(PixelAddress()) == 0) return;
;else
;{
;clearBlock();
;goto collision;
;}
;collision:
;dy != dy;
;y--;
;return;
;gameOver:
;gameOverFlag = true;
MOVEBALLDOWN:
LDA 1
CLC
ADC #1
STA 1
CMP #31
BEQ MOVEBALLDOWN_CHECKPADDLE
CMP #8
BCS MOVEBALLUP_END
JSR PIXELADDRESS
LDX #0
LDA ($3,X)
CMP #0
BEQ MOVEBALLDOWN_END
JSR CLEARBLOCK
JMP MOVEBALLDOWN_COLLISION
MOVEBALLDOWN_CHECKPADDLE:
LDA 0
CMP 6
BCC MOVEBALLDOWN_GAMEOVER
INC 6
INC 6
INC 6
INC 6
INC 6
INC 6
INC 6
INC 6
CMP 6
DEC 6
DEC 6
DEC 6
DEC 6
DEC 6
DEC 6
DEC 6
DEC 6
BCS MOVEBALLDOWN_GAMEOVER
JSR RANDOMANGLE
MOVEBALLDOWN_COLLISION:
LDA 2
EOR #1
STA 2
DEC 1
MOVEBALLDOWN_END:
RTS
MOVEBALLDOWN_GAMEOVER:
LDA #1
STA 7
RTS

;MOVEBALLLEFT routine
;Equivalent C:
;x--;
;if(x < 0) goto collision;
;if(y >= 8) return;
;if(*(PixelAddress()) == 0) return;
;else
;{
;clearBlock();
;goto collision;
;}
;collision:
;dx != dx;
;x++;
MOVEBALLLEFT:
LDA 0
SEC
SBC #1
STA 0
BCC MOVEBALLLEFT_COLLISION
LDA 1
CMP #8
BCS MOVEBALLLEFT_END
JSR PIXELADDRESS
LDX #0
LDA ($3,X)
CMP #0
BEQ MOVEBALLLEFT_END
JSR CLEARBLOCK
MOVEBALLLEFT_COLLISION:
LDA 2
EOR #2
STA 2
INC 0
MOVEBALLLEFT_END:
RTS

;MOVEBALLRIGHT routine
;Equivalent C:
;x++;
;if(x == 32) goto collision;
;if(y >= 8) return;
;if(*(PixelAddress()) == 0) return;
;else
;{
;clearBlock();
;goto collision;
;}
;collision:
;dx != dx;
;x--;
MOVEBALLRIGHT:
LDA 0
CLC
ADC #1
STA 0
CMP #32
BEQ MOVEBALLRIGHT_COLLISION
LDA 1
CMP #8
BCS MOVEBALLRIGHT_END
JSR PIXELADDRESS
LDX #0
LDA ($3,X)
CMP #0
BEQ MOVEBALLRIGHT_END
JSR CLEARBLOCK
MOVEBALLRIGHT_COLLISION:
LDA 2
EOR #2
STA 2
DEC 0
MOVEBALLRIGHT_END:
RTS

;UPDATEPADDLE routine
;Equivalent C code (actually approximate, also in the ASM I made the paddle larger):
;if(keyPressed == 0x61)
;{
;rngCounter += 3;
;if(paddleX > 0)
;{
;paddleX--;
;*((byte *) 0x5e1 + paddleX) = 1;
;goto draw;
;}
;}
;else if(keyPressed == 0x64)
;{
;rngCounter += 5;
;if(paddleX < 26)
;{
;paddleX++;
;*((byte *) 0x5df + paddleX) = 0;
;}
;}
;draw:
;*((byte *) 0x5e0 + paddleX) = 1;
;*((byte *) 0x5e1 + paddleX) = 1;
;*((byte *) 0x5e2 + paddleX) = 1;
;*((byte *) 0x5e3 + paddleX) = 1;
;*((byte *) 0x5e4 + paddleX) = 1;
UPDATEPADDLE:
LDA $FF
CMP #$61
BNE UPDATEPADDLE_CHECKD
INC 8
INC 8
INC 8
LDA 6
SEC
SBC #1
BCC UPDATEPADDLE_REDRAW
STA 6
TAX
LDA #0
STA $5E8,X
JMP UPDATEPADDLE_REDRAW
UPDATEPADDLE_CHECKD:
CMP #$64
BNE UPDATEPADDLE_REDRAW
INC 8
INC 8
INC 8
INC 8
INC 8
LDA 6
CLC
ADC #1
CMP #25
BCS UPDATEPADDLE_REDRAW
STA 6
TAX
LDA #0
STA $5DF,X
UPDATEPADDLE_REDRAW:
LDA 6
TAX
LDA #1
STA $5E0,X
STA $5E1,X
STA $5E2,X
STA $5E3,X
STA $5E4,X
STA $5E5,X
STA $5E6,X
STA $5E7,X
RTS

;CHECKBLOCKS routine
;Checks all 4 rows at the same loop iteration, for speed
;Equivalent C:
;for(int i = 0; !(i >= 8 * 4); i += 4)
;{
;if(*((byte *) 0x200 + i) != 0) return;
;if(*((byte *) 0x240 + i) != 0) return;
;if(*((byte *) 0x280 + i) != 0) return;
;if(*((byte *) 0x2C0 + i) != 0) return;
;}
;victory = true;
;return;
CHECKBLOCKS:
LDX #0
CHECKBLOCKS_LOOP:
LDA $200,X
CMP #0
BNE CHECKBLOCKS_GAMEISNOTOVER
LDA $240,X
CMP #0
BNE CHECKBLOCKS_GAMEISNOTOVER
LDA $280,X
CMP #0
BNE CHECKBLOCKS_GAMEISNOTOVER
LDA $2C0,X
CMP #0
BNE CHECKBLOCKS_GAMEISNOTOVER
INX
INX
INX
INX
CPX #$20
BCS CHECKBLOCKS_VICTORY
JMP CHECKBLOCKS_LOOP
CHECKBLOCKS_GAMEISNOTOVER:
RTS
CHECKBLOCKS_VICTORY:
LDA #2
STA 7
RTS

;RANDOMANGLE routine
;Changes the ball's angle "randomly"
;Explanation on ball angle:
;XXXXABCDE
;If E is set:	ball will move down
;If E is clear:	ball will move up
;If D is set:	ball will move left
;If D is clear:	ball will move right
;If A is set:	the ball will skip horizontal movement one out of two frames
;if B is set:	the ball will skip vertical movement one out of two frames
;X:				unused
;This function sets AB to 01, 10 or 11, effectively, a random number from 1 to 3
;Equivalent C:
;ballAngle = (ballAngle & 3) | (((rngCounter & 1) + ((rngCounter & 2) >> 1) + 1) << 2);
;Alternatively:
;temp = ballAngle & 3;
;ballAngle = rngCounter & 1;
;ballAngle = ((((rngCounter & 2) >> 1) + ballAngle + 1) << 2) | temp;
RANDOMANGLE:
LDA 2
AND #3
TAX
LDA 8
AND #1
STA 2
LDA 8
AND #2
LSR
CLC
ADC 2
ADC #1
ASL
ASL
STX 2
ORA 2
STA 2
RTS

END: