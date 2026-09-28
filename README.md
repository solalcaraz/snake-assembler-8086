# Snake en assembler 8086

El clásico Snake, escrito en assembler x86 de 16 bits para DOS. Lo hice como trabajo práctico en 2023 y lo retomé para dejarlo prolijo.

## Problema que resuelve

La consigna era hacer un juego en tiempo real y que se pudiera jugar, sin nada que te resuelva lo difícil: no hay librería gráfica, ni eventos de teclado, ni timers. Solo están las interrupciones del BIOS y de DOS y la memoria de video. Sin eso, me tocó resolver a mano:

- dibujar en pantalla y con color,
- leer el teclado sin frenar el juego,
- medir el tiempo para que la víbora avance a velocidad constante,
- detectar choques, hacer crecer la víbora y generar frutas al azar.

## Demo

![Partida completa: instrucciones, 6 frutas y choque contra la pared](docs/demo.gif)

Partida completa: pantalla de instrucciones, 6 frutas comidas, choque contra la pared y mensaje de game over. Va a velocidad real y los cuadros salen de la memoria de video del juego.

## Tecnologías

- **Assembler 8086**, sintaxis MASM/TASM, modelo `small`.
- **BIOS:** `int 10h` (video y cursor), `int 16h` (teclado), `int 1Ah` (reloj).
- **DOS:** `int 21h` (texto de instrucciones, puntaje y salida).
- **DOSBox** para correrlo y **JWasm** para ensamblarlo.

## Cómo funciona

El programa está en un solo archivo, [`snake.asm`](snake.asm), dividido en cinco secciones: datos, programa principal, lógica del juego, dibujo y servicios de BIOS.

**El loop.** Cada vuelta es un paso del juego: esperar, mover la víbora, leer la tecla, reponer la fruta si hace falta y redibujar. La espera usa el contador de ticks del reloj del BIOS (unos 18 por segundo) y un paso dura 5 ticks. Lo hice así en lugar de con un loop vacío porque el loop depende de la velocidad del procesador, mientras que el reloj va igual en cualquier máquina o configuración de DOSBox.

**Dibujo directo en memoria de video.** En vez de pedirle cada carácter al BIOS, escribo directo en el segmento `B800h`. Ahí cada celda de la pantalla ocupa 2 bytes (carácter y color), así que la celda (fila, columna) está en `fila*160 + columna*2`. Es más rápido y me deja elegir el color de cada celda. El cálculo está en una sola rutina, `calcularOffset`.

**La víbora es una lista en memoria.** Cada segmento ocupa 3 bytes: el carácter y la posición. La cabeza va primero, y su carácter (`^ v < >`) es a la vez el dibujo y la dirección. Para mover, cada segmento toma la posición del que tenía adelante. No borro el campo en cada paso: borro solo la cola y redibujo encima, y así la pantalla no parpadea. Al comer, agrego un segmento en la posición que acaba de dejar la cola.

**Choques leyendo la pantalla.** Para saber si la cabeza choca con el cuerpo no recorro la lista: leo qué carácter hay en la celda a la que llega. Si es una `O`, perdiste; si es una `@`, comiste. Las paredes las detecto comparando coordenadas.

**En horizontal avanza de a 2 columnas.** Las celdas de texto son el doble de altas que de anchas. Si avanzara de a una columna, la víbora iría visiblemente más lenta de costado que hacia arriba. La consecuencia es que la cabeza solo pisa columnas pares, así que la fruta también se sortea solo en columnas pares, porque si no sería imposible de comer.

**Azar con el reloj.** La posición de la fruta sale del resto de dividir el contador de ticks. Si cae sobre la víbora, se sortea de nuevo.

**Otros detalles.** No se puede girar 180° porque la cabeza chocaría con el cuello. El puntaje se imprime con una rutina recursiva que divide por 10 y apila los restos, para que los dígitos salgan en orden.

## Cómo correrlo

Necesitás [DOSBox](https://www.dosbox.com/) y un ensamblador compatible con MASM. La opción más directa es [JWasm](https://github.com/Baron-von-Riedesel/JWasm): es libre, corre en Windows y arma el `.exe` sin linker:

```
jwasm -mz snake.asm
```

Eso genera `SNAKE.EXE`. Después, en DOSBox:

```
mount c C:\ruta\a\la\carpeta
c:
snake
```

**Controles:** `W` `A` `S` `D` para moverte y `Q` para salir. Van en minúscula, así que con Bloq Mayús activado no responden.

## Qué aprendí y qué mejoraría

**Aprendí:**

- Cómo se ve una computadora sin sistema operativo moderno: la pantalla es memoria, el teclado es un buffer y el tiempo es un contador que avanza solo.
- A definir y respetar a mano qué registros recibe, devuelve y modifica cada rutina. En assembler nadie te avisa si una llamada te pisa un registro que necesitabas.
- Que nadie controla los límites por vos. Revisando el código tiempo después encontré y corregí tres bugs:
  - la fruta podía aparecer sobre la pared derecha, y si ibas a comerla la víbora se escapaba del campo;
  - el cuerpo se guardaba en un buffer de 16 segmentos, así que al comer la fruta 15 pisaba las variables de al lado y el juego terminaba solo;
  - con puntaje 0 no se mostraba ningún número.

**Mejoraría:**

- **Leer la tecla antes de mover.** Hoy se lee después, así que cada giro se ve recién en el paso siguiente y se siente un poco de retraso.
- **Aceptar mayúsculas y flechas**, no solo `wasd`.
- **Leer los caracteres directo de la memoria de video** en lugar de usar el BIOS. Sería más simple y, además, el cursor dejaría de saltar por la pantalla.
- **Agregar una condición de victoria.** Si la víbora llena el campo, no queda lugar para la fruta y el juego se cuelga buscándolo.
- **Subir la velocidad a medida que crece el puntaje.**
