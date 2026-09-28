# Snake en assembler 8086

El clásico Snake, escrito en assembler x86 de 16 bits para DOS. Es el trabajo práctico final de la materia **SPD** (Tecnicatura en Programación Informática, UNSAM, 2023), hecho en equipo.

## Problema que resuelve

La consigna pedía un juego en tiempo real que se pudiera jugar, usando solo las interrupciones del BIOS y de DOS y la memoria de video. Sin librerías ni motor de juego de por medio, todo lo que en un lenguaje de alto nivel viene resuelto hubo que hacerlo a mano:

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
- **TASM** (Turbo Assembler) para ensamblarlo y **DOSBox** para correrlo.

## Cómo funciona

El programa está en un solo archivo, [`snake.asm`](snake.asm), dividido en cinco secciones: datos, programa principal, lógica del juego, dibujo y servicios de BIOS.

**El loop.** Cada vuelta es un paso del juego: esperar, mover la víbora, leer la tecla, reponer la fruta si hace falta y redibujar. La espera usa el contador de ticks del reloj del BIOS (unos 18 por segundo) y un paso dura 5 ticks. Descartamos el loop vacío porque su duración depende de la velocidad del procesador; el reloj, en cambio, va igual en cualquier máquina o configuración de DOSBox.

**Dibujo directo en memoria de video.** En vez de pedirle cada carácter al BIOS, escribimos directo en el segmento `B800h`. Ahí cada celda de la pantalla ocupa 2 bytes (carácter y color), así que la celda (fila, columna) está en `fila*160 + columna*2`. Es más rápido y permite elegir el color de cada celda. El cálculo vive en una sola rutina, `calcularOffset`.

**La víbora es una lista en memoria.** Cada segmento ocupa 3 bytes: el carácter y la posición. La cabeza va primero, y su carácter (`^ v < >`) es a la vez el dibujo y la dirección. Para mover, cada segmento toma la posición del que tenía adelante. El campo no se borra en cada paso: se borra solo la cola y se redibuja encima, y así la pantalla no parpadea. Al comer, se agrega un segmento en la posición que acaba de dejar la cola.

**Choques leyendo la pantalla.** Para saber si la cabeza choca con el cuerpo no recorremos la lista: leemos qué carácter hay en la celda a la que llega. Si es una `O`, perdiste; si es una `@`, comiste. Las paredes se detectan comparando coordenadas.

**En horizontal avanza de a 2 columnas.** Las celdas de texto son el doble de altas que de anchas. Si avanzara de a una columna, de costado iría visiblemente más lenta que hacia arriba. La consecuencia es que la cabeza solo pisa columnas pares, así que la fruta también se sortea solo en columnas pares. Si no, podría caer en un lugar imposible de alcanzar.

**Azar con el reloj.** La posición de la fruta sale del resto de dividir el contador de ticks. Si cae sobre la víbora, se sortea de nuevo.

**Otros detalles.** No se puede girar 180°, porque la cabeza chocaría con el cuello. El puntaje se imprime con una rutina recursiva que divide por 10 y apila los restos, para que los dígitos salgan en orden.

## Cómo correrlo

Se ensambla con TASM y se corre en DOSBox.

**Controles:** `W` `A` `S` `D` para moverte y `Q` para salir.

## Qué aprendí y qué mejoraría

**Qué aprendí**

- A programar en bajo nivel: trabajar directo con registros (`AX`, `BX`, `CX`, `DX`, `SI`, `DI`) y segmentos (`DS` para los datos, `ES` apuntando a la memoria de video).
- A usar la pila para guardar y recuperar registros entre llamadas (`push`/`pop`), y a definir qué recibe y qué devuelve cada rutina.
- A pedirle cosas al hardware con interrupciones: `int 10h` para la pantalla, `int 16h` para el teclado, `int 1Ah` para el reloj e `int 21h` para DOS.
- A controlar el flujo con comparaciones y saltos condicionales (`cmp`, `je`, `jne`, `jl`, `loop`) en lugar de `if` y `for`.
- A hacer cuentas con `mul` y `div`, por ejemplo para calcular posiciones en pantalla o sacar un número al azar del resto de una división.

**Qué mejoraría**

- **Mejor azar para la fruta.** La fila y la columna salen del mismo valor del reloj, así que no son independientes y la fruta tiende a repetir patrones. Usaría un generador pseudoaleatorio simple (por ejemplo, un LCG) con el reloj solo como semilla.
- **Respuesta del teclado.** La tecla se lee después de mover, así que cada giro recién se ve en el paso siguiente. Y como se consume una sola tecla por paso, si apretás varias rápido quedan en cola y la víbora gira tarde. Leería la tecla antes de mover y vaciaría el buffer en cada paso.
- **Mayúsculas.** Solo reconoce `w a s d q` en minúscula: con Bloq Mayús activado, el juego no responde.
- **Dificultad progresiva y reintento.** La velocidad es fija toda la partida y, al perder, el programa vuelve a DOS. Bajaría `delayticks` con cada fruta y agregaría una opción para jugar de nuevo.

## Autoría y mejoras

Este repositorio es el original del trabajo práctico final de SPD que hicimos en equipo en noviembre de 2023. El tag [`tp-original-2023`](https://github.com/solalcaraz/snake-assembler-8086/tree/tp-original-2023) marca el TP tal como lo entregamos.

**Equipo:** Damián Palomba, Christian León Cáceres, Víctor Manquez, Gabriel Carpio y Sol Alcaraz.

**Lo que hice después**:

- Renombré el fuente a `snake.asm`, puse nombres claros a variables y rutinas, dejé solo los comentarios que explican algo no obvio y ordené el archivo en secciones.
- Saqué código muerto y unifiqué en `calcularOffset` el cálculo de posición en pantalla, que estaba repetido.
- Corregí tres bugs:
  - La fruta podía aparecer sobre la pared derecha.
  - Al comer la fruta número 15, el cuerpo se salía del espacio reservado en memoria, pisaba las variables siguientes y el juego terminaba solo. Ahora el espacio alcanza para la víbora más larga posible.
  - Con puntaje 0 se veía "Puntaje:" sin ningún número, porque la rutina que imprime números no contemplaba el cero.
- Agregué el `.gitignore`, grabé la demo y escribí este README.

Para comprobar que la limpieza no cambiaba el juego, corrí 71 partidas simuladas en un emulador determinista y comparé las pantallas contra el original: eran idénticas.
