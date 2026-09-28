; =============================================================================
; SNAKE para DOS en assembler 8086 (MASM/TASM, modelo small)
;
; Todo se dibuja escribiendo directo en la memoria de video de modo texto
; (segmento B800h): cada celda ocupa 2 bytes, el carácter y su atributo de
; color, así que la celda (fila, col) está en el offset fila*160 + col*2.
; El teclado se lee por BIOS (int 16h) sin bloquear y el tiempo se mide con
; el contador de ticks del reloj (int 1Ah, ~18,2 ticks por segundo).
;
; Secciones del archivo:
;   1. Constantes y datos
;   2. Programa principal
;   3. Lógica del juego      (mover, leer dirección, generar fruta)
;   4. Dibujo en pantalla    (tablero, campo, caracteres, texto y números)
;   5. Servicios de BIOS     (espera, teclado, cursor)
; =============================================================================

.8086
.model small
.stack 100h

; =============================================================================
; 1. CONSTANTES Y DATOS
;
; El campo es un rectángulo de col x fil celdas cuya esquina superior
; izquierda está en (arriba, izq). Las filas 0 y 1 quedan libres para el
; título y el puntaje.
;
; La víbora se guarda como una lista de segmentos de 3 bytes cada uno:
;   byte 0     carácter a dibujar
;   bytes 1-2  posición como word: byte bajo = columna, byte alto = fila
; "cabeza" es el primer segmento y su carácter (^ v < >) indica además hacia
; dónde se mueve. Inmediatamente después en memoria viene "snake", el cuerpo,
; y la lista termina en el primer segmento en cero.
; =============================================================================
izq     equ 0
arriba  equ 2
fil     equ 20
col     equ 40
derecha equ izq+col
fondo   equ arriba+fil

.data
    msg         db "Jueguito snake",0
    manual      db 0ah,0dh,"Movete con WASD",0ah,0dh,"Presiona Q para salir",0ah,0dh,"Presiona cualquier tecla para empezar.$"
    quitmsg     db "Gracias por jugar a snake c:",0
    gameovermsg db "Que paso flaco te moriste?",0
    puntaje     db "Puntaje: ",0

    cabeza      db "^",10,10
    snake       db "O",10,11, 3*15 DUP(0)
    largo       db 1            ; segmentos del cuerpo; el puntaje es largo-1

    hayfruta    db 1            ; 0 = la fruta fue comida y hay que generar otra
    frutax      db 8
    frutay      db 8

    perdio      db 0
    salir       db 0
    delayticks  db 5            ; ticks de reloj por paso; el main lo cambia para las pantallas finales
    color       db 01101010b    ; atributo del campo: fondo marrón (6), texto verde claro (10)

.code

; =============================================================================
; 2. PROGRAMA PRINCIPAL
;
; Muestra las instrucciones, espera una tecla, dibuja el tablero y entra al
; loop del juego. Cada vuelta del loop es un paso:
;   esperar -> mover la víbora -> leer la tecla -> reponer la fruta -> redibujar
; La tecla se lee después de mover, así que un giro recién se ve en el paso
; siguiente. El juego termina por game over o porque el jugador apretó Q; en
; los dos casos muestra un mensaje unos segundos antes de volver a DOS.
; =============================================================================
main proc far
    mov ax, @data
    mov ds, ax

    mov ax, 0B800h              ; ES apunta a la memoria de video durante todo el programa
    mov es, ax

    mov ax, 0003h               ; modo texto 80x25; de paso limpia la pantalla
    int 10h

    lea bx, msg
    xor dx, dx
    call escribirString

    lea dx, manual
    mov ah, 09h
    int 21h

    mov ah, 07h                 ; espera una tecla cualquiera
    int 21h
    call dibujarTablero

loopJuego:
    call delay
    lea bx, msg
    xor dx, dx
    call escribirString

    call moverSnake
    cmp perdio, 1
    je finPerdio

    call leerDireccion
    cmp salir, 1
    je finSalir
    call generarFruta
    call dibujarCampo
    jmp loopJuego

finPerdio:
    mov ax, 0003h
    int 10h
    mov delayticks, 100
    mov dx, 0000h
    lea bx, gameovermsg
    call escribirString
    call delay
    jmp finPrograma

finSalir:
    mov ax, 0003h
    int 10h
    mov delayticks, 50
    mov dx, 0000h
    lea bx, quitmsg
    call escribirString
    call delay

finPrograma:
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h
main endp

; =============================================================================
; 3. LÓGICA DEL JUEGO
;
; moverSnake    avanza un paso y detecta si comió o chocó
; leerDireccion interpreta WASD / Q
; generarFruta  ubica una fruta nueva cuando la anterior fue comida
;
; Los choques se detectan de dos formas: contra las paredes comparando la
; posición con los bordes, y contra el cuerpo leyendo qué carácter hay en
; pantalla en la celda de destino.
; =============================================================================

; Avanza la víbora un paso en la dirección de la cabeza y detecta si comió
; la fruta o si chocó (contra una pared o contra su propio cuerpo).
; Cada segmento del cuerpo pasa a la posición del que tenía adelante.
moverSnake proc
    lea bx, cabeza
    xor ax, ax
    mov al, [bx]
    push ax                     ; carácter de la cabeza = dirección
    inc bx
    mov ax, [bx]                ; posición de la cabeza, que hereda el primer segmento
    add bx, 2
mover_cuerpo:
    cmp word ptr [bx], 0        ; segmento en cero: se terminó la lista
    je mover_finCuerpo
    inc bx
    mov dx, [bx]
    mov [bx], ax                ; el segmento toma la posición del anterior...
    mov ax, dx                  ; ...y la suya pasa al siguiente
    add bx, 2
    jmp mover_cuerpo
mover_finCuerpo:
    pop ax
    push dx                     ; posición que dejó libre la cola
    lea bx, cabeza
    inc bx
    mov dx, [bx]

    ; En horizontal avanza de a 2 columnas porque las celdas de texto son el
    ; doble de altas que de anchas: así se mueve a la misma velocidad visual.
    cmp al, '<'
    jne mover_noIzq
    dec dl
    dec dl
    jmp mover_cabezaLista
mover_noIzq:
    cmp al, '>'
    jne mover_noDer
    inc dl
    inc dl
    jmp mover_cabezaLista
mover_noDer:
    cmp al, '^'
    jne mover_abajo
    dec dh
    jmp mover_cabezaLista
mover_abajo:
    inc dh

mover_cabezaLista:
    mov [bx], dx
    call leerCaracter           ; qué hay en la celda a la que llega la cabeza

    cmp bl, '@'
    je mover_comio

    mov cx, dx
    pop dx
    cmp bl, 'O'
    je mover_perdio
    mov bl, 0                   ; borra la cola
    call escribirCaracter
    mov dx, cx

    cmp dh, arriba
    je mover_perdio
    cmp dh, fondo
    je mover_perdio
    cmp dl, izq
    je mover_perdio
    cmp dl, derecha
    je mover_perdio
    ret
mover_perdio:
    inc perdio
    ret
mover_comio:
    ; Crece: agrega un segmento al final del cuerpo, en la posición que
    ; acaba de dejar la cola (así no se borra en este paso).
    mov al, largo
    xor ah, ah
    lea bx, snake
    mov cx, 3
    mul cx                      ; offset del nuevo segmento = largo * 3

    pop dx
    add bx, ax
    mov byte ptr ds:[bx], 'O'
    mov [bx+1], dx
    inc largo
    mov dh, frutay
    mov dl, frutax
    mov bl, 0
    call escribirCaracter
    mov hayfruta, 0
    ret
moverSnake endp

; Lee WASD para cambiar la dirección y Q para salir.
; Ignora el giro de 180 grados: la cabeza chocaría con su propio cuerpo.
leerDireccion proc
    call leerTecla
    cmp dl, 0
    je leerDireccion_q

    cmp dl, 'w'
    jne leerDireccion_noW
    cmp cabeza, 'v'
    je leerDireccion_q
    mov cabeza, '^'
    ret
leerDireccion_noW:
    cmp dl, 'a'
    jne leerDireccion_noA
    cmp cabeza, '>'
    je leerDireccion_q
    mov cabeza, '<'
    ret
leerDireccion_noA:
    cmp dl, 's'
    jne leerDireccion_noS
    cmp cabeza, '^'
    je leerDireccion_q
    mov cabeza, 'v'
    ret
leerDireccion_noS:
    cmp dl, 'd'
    jne leerDireccion_q
    cmp cabeza, '<'
    je leerDireccion_q
    mov cabeza, '>'
leerDireccion_q:
    cmp dl, 'q'
    je leerDireccion_salir
    ret
leerDireccion_salir:
    inc salir
    ret
leerDireccion endp

; Si la fruta fue comida, elige una posición nueva al azar dentro del campo.
; El azar sale del contador de ticks del reloj.
generarFruta proc
    mov ch, frutay              ; posición anterior, para no repetirla
    mov cl, frutax
fruta_sortear:
    cmp hayfruta, 1
    je fruta_fin
    mov ah, 00h
    int 1Ah
    push dx
    mov ax, dx
    xor dx, dx
    xor bh, bh
    mov bl, fil
    dec bl
    div bx
    mov frutay, dl              ; resto entre 0 y fil-2
    inc frutay                  ; +1 para no caer sobre el borde superior

    pop ax                      ; mismos ticks, ahora para la columna
    mov bl, col
    dec dl
    xor dx, dx
    xor bh, bh
    div bx
    mov frutax, dl
    inc frutax

    cmp frutax, cl
    jne fruta_posDistinta
    cmp frutay, ch
    jne fruta_posDistinta
    jmp fruta_sortear

fruta_posDistinta:
    ; La cabeza avanza de a 2 columnas y arranca en una par, así que solo pasa
    ; por columnas pares: una fruta en columna impar sería imposible de comer.
    mov al, frutax
    ror al, 1
    jc fruta_sortear

    add frutay, arriba
    add frutax, izq

    ; Si cae sobre la víbora, se sortea de nuevo.
    mov dh, frutay
    mov dl, frutax
    call leerCaracter
    cmp al, 'O'
    je fruta_sortear
    cmp al, '^'
    je fruta_sortear
    cmp al, '<'
    je fruta_sortear
    cmp al, '>'
    je fruta_sortear
    cmp al, 'v'
    je fruta_sortear
fruta_fin:
    ret
generarFruta endp

; =============================================================================
; 4. DIBUJO EN PANTALLA
;
; Todas las rutinas reciben la posición en DH (fila) y DL (columna) y
; escriben directo en la memoria de video (ES = B800h). La excepción son los
; números del puntaje, que se imprimen con DOS en la posición del cursor.
; =============================================================================

; Dibuja el borde del campo con '#' (en sentido horario desde la esquina
; superior izquierda) y rellena el interior con espacios del color del campo.
dibujarTablero proc
    mov ax, 0003h
    int 10h

    mov dh, arriba
    mov dl, izq
    mov cx, col
    mov bl, '#'
tablero_bordeSuperior:
    call escribirCaracter
    inc dl
    loop tablero_bordeSuperior
    mov cx, fil
tablero_bordeDerecho:
    call escribirCaracter
    inc dh
    loop tablero_bordeDerecho
    mov cx, col
tablero_bordeInferior:
    call escribirCaracter
    dec dl
    loop tablero_bordeInferior
    mov cx, fil
tablero_bordeIzquierdo:
    call escribirCaracter
    dec dh
    loop tablero_bordeIzquierdo

    mov dh, arriba+1
    mov bl, ' '
tablero_rellenoFila:
    mov dl, izq+1
    mov cx, col
    dec cx
tablero_rellenoCol:
    call escribirCaracter
    inc dl
    loop tablero_rellenoCol
    inc dh
    cmp dh, fondo
    jl tablero_rellenoFila
    ret
dibujarTablero endp

; Redibuja el puntaje, la víbora y la fruta. No hace falta borrar el campo:
; moverSnake ya borró la cola, así que alcanza con pisar lo que cambió.
dibujarCampo proc
    lea bx, puntaje
    mov dx, 0100h
    call escribirString
    add dl, 9                   ; largo de "Puntaje: "
    call posCursor              ; imprimirNum escribe por DOS, en la posición del cursor
    mov al, largo
    dec al
    xor ah, ah
    call imprimirNum

    lea si, cabeza
dibujarCampo_loop:
    mov bl, ds:[si]
    test bl, bl
    jz dibujarCampo_fruta
    mov dx, ds:[si+1]
    call escribirCaracter
    add si, 3
    jmp dibujarCampo_loop

dibujarCampo_fruta:
    mov bl, '@'
    mov dh, frutay
    mov dl, frutax
    call escribirCaracter
    mov hayfruta, 1
    ret
dibujarCampo endp

; Escribe el carácter BL con el color del campo en la fila DH, columna DL.
escribirCaracter proc
    call calcularOffset
    mov bh, color
    mov es:[di], bl
    mov es:[di+1], bh
    ret
escribirCaracter endp

; Escribe el string terminado en 0 apuntado por BX en la fila DH, columna DL.
; Solo escribe caracteres: conserva el color que ya tenía cada celda.
escribirString proc
    call calcularOffset
escribirString_loop:
    mov al, [bx]
    test al, al
    jz escribirString_fin
    mov es:[di], al
    inc di
    inc di
    inc bx
    jmp escribirString_loop
escribirString_fin:
    ret
escribirString endp

; Devuelve en DI (y en AX) el offset en memoria de video de la fila DH,
; columna DL: fila*160 + col*2. Conserva BX y DX.
calcularOffset proc
    push bx
    push dx
    mov al, dh
    mov bl, 160
    mul bl
    xor dh, dh
    shl dx, 1
    add ax, dx
    mov di, ax
    pop dx
    pop bx
    ret
calcularOffset endp

; Imprime AX en decimal. Recursiva: divide por 10 y apila el resto, de modo
; que los dígitos salen en orden al ir volviendo de las llamadas.
imprimirNum proc
    test ax, ax
    jz imprimirNum_fin
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    call imprimirNum
    pop dx
    call imprimirDigito
imprimirNum_fin:
    ret
imprimirNum endp

; Imprime por DOS el dígito DL (0-9) en la posición del cursor.
imprimirDigito proc
    add dl, '0'
    mov ah, 02h
    int 21h
    ret
imprimirDigito endp

; =============================================================================
; 5. SERVICIOS DE BIOS
;
; Envoltorios chicos sobre las interrupciones de reloj (1Ah), teclado (16h)
; y video (10h) que usa el resto del programa.
; =============================================================================

; Espera "delayticks" ticks de reloj.
; Solo compara el byte bajo de la diferencia: alcanza porque las esperas son
; cortas (menos de 128 ticks, jl compara con signo).
delay proc
    mov ah, 00h                 ; int 1Ah, función 00h: contador de ticks en CX:DX
    int 1Ah
    mov bx, dx
delay_loop:
    int 1Ah
    sub dx, bx
    cmp dl, delayticks
    jl delay_loop
    ret
delay endp

; Lee una tecla sin bloquear. Devuelve su ASCII en DL, o 0 si no hay ninguna.
leerTecla proc
    mov ah, 01h                 ; hay tecla en el buffer? (ZF=1 si no)
    int 16h
    jnz leerTecla_hay
    xor dl, dl
    ret
leerTecla_hay:
    mov ah, 00h                 ; la saca del buffer
    int 16h
    mov dl, al
    ret
leerTecla endp

; Devuelve en BL (y en AL) el carácter que hay en la fila DH, columna DL.
leerCaracter proc
    call posCursor
    mov ah, 08h
    int 10h
    mov bl, al
    ret
leerCaracter endp

; Mueve el cursor de la página 0 a la fila DH, columna DL.
posCursor proc
    mov ah, 02h
    mov bh, 00h
    int 10h
    ret
posCursor endp

end main
