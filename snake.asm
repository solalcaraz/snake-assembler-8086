.8086
.model small
.stack 100h

;constantes bordes del campo
izq equ 0
arriba equ 2
fil equ 20
col equ 40
derecha equ izq+col
fondo equ arriba+fil

.data          
    msg db "Jueguito snake",0
    manual db 0ah,0dh,"Movete con WASD",0ah,0dh,"Presiona Q para salir",0ah,0dh,"Presiona cualquier tecla para empezar.$"
    quitmsg db "Gracias por jugar a snake c:",0
    gameovermsg db "Que paso flaco te moriste?", 0
    puntaje db "Puntaje: ",0
    cabeza db "^",10,10
    snake db "O",10,11, 3*15 DUP(0)
    largo db 1
    hayfruta db 1
    frutax db 8
    frutay db 8
    perdio db 0
    salir db 0   
	delayticks db 5
    color db 01101010b

.code

main proc far
	mov ax, @data
	mov ds, ax 
	
	mov ax, 0b800H
	mov es, ax

	mov ax, 0003H 	;limpio la pantalla
	int 10H
	
	lea bx, msg
	xor dx, dx
	call escribirString
	
	lea dx, manual
	mov ah, 09h
	int 21h
	
	mov ah, 07h
	int 21h
	mov ah, 03h
	int 10H
    call imprimirCuadro
    
    
mainloop:
    call delay             
    lea bx, msg
	xor dx, dx
	call escribirString
	
    call muevoSnake
    cmp perdio,1
    je gameover_mainloop
    
    call calcularCabeza
    cmp salir, 1
    je quieresalir
    call operacionFruta
    call imprimirCampo
    jmp mainloop
    
gameover_mainloop: 
    mov ax, 0003H
	int 10H
    mov delayticks, 100
    mov dx, 0000H
    lea bx, gameovermsg
    call escribirString
    call delay    
    jmp quit_mainloop    
    
quieresalir:
    mov ax, 0003H
	int 10H    
    mov delayticks, 50
    mov dx, 0000H
    lea bx, quitmsg
    call escribirString
    call delay    
    jmp quit_mainloop    

quit_mainloop:
    mov ax, 0003H
    int 10h    
    mov ax, 4c00h
    int 21h  
main endp
  
  
;ESPERA CIERTA CANTIDAD DE SEGUNDOS  
delay proc
    ; Obtener el tiempo actual
    mov ah, 00         ; Función 2 de la interrupción 1Ah (servicio para leer la hora)
    int 1Ah           ; Llamar a la interrupción 1Ah

    ; Guardar el tiempo actual en BX
    mov bx, dx

delay_loop:
    ; Obtener el tiempo actual
    int 1Ah          
    ; Comparar con el tiempo objetivo
    sub dx, bx
    cmp dl, delayticks
    jl delay_loop
	
    ret

delay endp

operacionFruta proc
	mov ch, frutay
	mov cl, frutax
randofrutar:
	cmp hayfruta, 1
	je chau
	mov ah,00  ;int para llamar a la hora del reloj
	int 1Ah    ;guarda en al, cx, dx
	push dx	   ;guardo la hora
	mov ax, dx
	xor dx, dx
	xor bh, bh
	mov bl, fil
	dec bl
	div bx
	mov frutaY, dl ;resto de la division esta en el rango de 0-19
	inc frutaY	   ;no queremos que quede dentro de la pared :)
	
	pop ax	  ;reutilizo la hora
	mov bl, col
	dec dl
	xor dx, dx
	xor bh, bh
	div bx
	mov frutaX, dl ;resto de la division esta en el rango de 0-39
	inc frutaX	   

	cmp frutaX, cl ;no puede caer en la misma posicion
	jne correcto
	cmp frutaY, ch
	jne correcto
	jmp randofrutar
	
correcto:
	mov al, frutax
	ror al, 1
	jc randofrutar
	
	add frutay, arriba
	add frutax, izq

;Chequeo colisiones para randomizar de nuevo
	mov dh, frutay
	mov dl, frutax
	call leoCaracter
	cmp al, 'O'
	je randofrutar
	cmp al, '^'
	je randofrutar
	cmp al, '<'
	je randofrutar
	cmp al, '>'
	je randofrutar
	cmp al, 'v'
	je randofrutar
chau:
	ret
operacionFruta endp
	
muevoSnake proc
	lea bx, cabeza
	xor ax, ax
	mov al, [bx]
	push ax    ;guardamos la cabecita
	inc bx
	mov ax, [bx]
	add bx, 2	;seguimos de largo, nos topamos con el cuerpo en el data segment
	xor cx, cx
muevoLoop:
	mov si, [bx]     ;recorremos el cuerpo
    test si, [bx]    ;si SI AND [bx] es cero, nos salimos del cuerpo. 
    jz nosSalimos	 ;(el arreglo cuerpo está relleno de ceros al final)
    inc cx     		
    inc bx			
    mov dx,[bx]
    mov [bx], ax	;a medida q recorremos guardamos en dx la direccion del segmento
    mov ax,dx
    add bx,2
    jmp muevoLoop
nosSalimos:
	pop ax 		;recupero la cabeza
	push dx 	;guardo la direc. del ultimo secmento
	lea bx, cabeza
	inc bx
	mov dx, [bx]
	
    cmp al, '<'
    jne mal1
    dec dl
    dec dl
    jmp listocabeza
mal1:
    cmp al, '>'
    jne mal2            
    inc dl 
    inc dl
    jmp listocabeza
    
mal2:
    cmp al, '^'
    jne mal3
    dec dh
    jmp listocabeza
    
mal3:
    inc dh ;si o si es V
    
listocabeza:
	mov [bx], dx  ;en dx esta la proxima coordenada del snake
	call leoCaracter
	
	cmp bl, '@'
	je comioFruta
	
	mov cx, dx
	pop dx
	cmp bl, 'O'
	je gameOver
	mov bl, 0
	call escribirCaracter
	mov dx, cx
	
	cmp dh, arriba
    je gameOver
    cmp dh, fondo
    je gameOver
    cmp dl, izq
    je gameOver
    cmp dl, derecha
    je gameOver
	ret
gameOver:
	inc perdio
	ret
comioFruta:
	mov al, largo
	xor ah,ah
	lea bx, snake
	mov cx, 3 ;busco el indice del cuerpo, (largo x 3 (cada segmento tiene 3 bytes))
	mul cx	
	
	pop dx ;direcc. del ultimo segmento de antes
	add bx, ax
	mov byte ptr ds:[bx], 'O'
	mov [bx+1], dx
	inc largo
	mov dh, frutay
	mov dl, frutax
	mov bl, 0
	call escribirCaracter
	mov hayfruta,0
	ret
	
muevoSnake endp
	
escribirString proc     ;escribe string en la posicion del cursor
    push dx
    mov ax, dx
    and ax, 0FF00H
    mov al, ah
    
    push bx
    mov bh, 160
    mul bh
    
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
loop_string:
	mov al, [bx]
    test al, al
    jz salir_string
    mov es:[di], al
    inc di
    inc di
    inc bx
    jmp loop_string
salir_string:
	pop dx
    ret
escribirString endp         
	

		  
leerTecla proc   ;DL contiene el carácter ASCII si se presiona una tecla, sino dl contiene 0.

    mov ah, 01H ;01H Verifica si hay tecla presionada
    int 16H 
    jnz teclaSi ;Salta si se presiono una tecla
    xor dl, dl  ;dl=0
    ret
teclaSi:
    mov ah, 00H ;00H Lee código de tecla presionada
    int 16H     ;Llama a la interrupción 16H
    mov dl,al   ;guarda la tecla en dl
    ret
	
leerTecla endp        

leoCaracter proc ;recibo coordenadas dh = fila, dl = columna, devuelvo en bl el ascii que se encuentre ahi.
	call posCursor
	mov ah, 8h
	int 10h
	mov bl, al
	ret
leoCaracter endp


imprimirCampo proc
	lea bx, puntaje
	mov dx, 0100h
	call escribirString
	add dl, 9
	call posCursor
	mov al, largo
	dec al
	xor ah, ah
	call imprimirNum
	lea si, cabeza
    push cx
imprimirLoop:
    mov ch, 10010011b 
	mov bl, ds:[si]
	test bl, bl
	jz imprimirListo
	mov dx, ds:[si+1]   ;recorro el cuerpo del snake, imprimo todo hasta ver un cero
	call escribirCaracter
	add si,3			;cada segmento ocupa tres direcciones.
	jmp imprimirLoop

imprimirListo:
    pop cx
	mov bl, '@'
	mov dh, frutay
	mov dl, frutax
	call escribirCaracter
	mov hayfruta, 1
	ret
imprimirCampo endp

calcularCabeza proc

    call leerTecla     ;llama a la subrutina anterior que solo se usa para la funcion compara
    cmp dl, 0          ;si dl es 0 no se presiono ninguna tecla
    je opSiguiente4
    
    cmp dl, 'w'             ;compara letra con "WASD" una por una
    jne opSiguiente1        ;si encuentra una igualdad cambia la direccion del snake, sino salta a la siguiente comparacion
    cmp cabeza, 'v'  		;si las direcciones actual y nueva son opuestas, no hace nada
    je  opSiguiente4
    mov cabeza, '^'
    ret
opSiguiente1:
    cmp dl, 'a'
    jne opSiguiente2
    cmp cabeza, '>'
    je  opSiguiente4
    mov cabeza, '<'
    ret
opSiguiente2:
    cmp dl, 's'
    jne opSiguiente3
    cmp cabeza, '^'
    je  opSiguiente4
    mov cabeza, 'v'
    ret
opSiguiente3:
    cmp dl, 'd'
    jne opSiguiente4
    cmp cabeza, '<'
    je  opSiguiente4
    mov cabeza,'>'
opSiguiente4:
    cmp dl, 'q'   ;letra con la que se va a salir del juego
    je finCompara
    ret    

finCompara:
    inc salir
    ret
	
calcularCabeza endp
		  
          
imprimirCuadro proc
    ;Limpiar la pantalla
    mov ah, 00h
    mov al, 03h
    int 10h
;Dimensiones del campo (80x25)

;Borde izquierdo
    mov dh, arriba
    mov dl, izq
    mov cx, col ;Número de columnas maximas
    mov bl, '#' 
    mov si, 03h   
imp1:
    call escribirCaracter
    inc dl
    loop imp1
    mov cx, fil
imp2:
    call escribirCaracter
    inc dh
    loop imp2
    mov cx, col
imp3:
    call escribirCaracter
    dec dl
    loop imp3
    mov cx, fil
imp4:
    call escribirCaracter
    dec dh
    loop imp4

    mov dh, 3
    mov dl, 1
    mov bl, ' '
impcol:
    mov dl, 1
    mov cx, col
    dec cx
col_loop:
    call escribirCaracter
    inc dl
    loop col_loop
    inc dh
    cmp dh, 22
    jl impcol



ret

imprimirCuadro endp

posCursor proc     
    mov ah, 02h       	;Subservicio 02h: Establecer posición del cursor
    mov bh, 00h			;dh = fila, dl = columna, bh = pagina
    int 10h           
    ret
    posCursor endp



escribirCaracter proc

    push dx
    mov ax, dx
    and ax, 0FF00H
    mov al, ah
    
    push bx
    mov bh, 160
    mul bh 
    pop bx
    and dx, 0FFH
    shl dx,1
    add ax, dx
    mov di, ax
    mov bh, color
    mov es:[di], bl
    mov es:[di+1], bh
    pop dx
    ret    			
escribirCaracter endp		  
	
imprimirDigito proc
    add dl, '0'
    mov ah, 02H
    int 21H
    ret
imprimirDigito endp   
	
imprimirNum proc   ;en ax el numero a imprimir
    test ax,ax
    jz esCero
    xor dx, dx
   
    mov bx,10
    div bx
    push dx			  ;guarda los restos en el stack
    call imprimirNum  ;recursividad en assembler? inaudito
    pop dx			  ;los escupe en orden opuesto
    call imprimirDigito	;y los imprime
    ret
esCero:
    mov ah, 02  
    ret    
imprimirNum endp  	
	  
end
