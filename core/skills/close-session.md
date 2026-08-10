---
command: close-session
capability: Cerrar la sesión sin perder nada
handoff: Capturar algo al vuelo
---

# close-session — cerrar distribuyendo lo que dejó la sesión

Una sesión que termina deja material que no está en ningún archivo. Esto lo reparte a los canónicos
del nodo cargado y termina con un veredicto honesto: qué se capturó, qué **no**, y por dónde se
retoma.

## Las dos preguntas

Se hacen las dos, siempre, en este orden:

1. **¿Qué no puede perderse de esta sesión?** De la respuesta salen decisiones, aprendizajes y
   pendientes.
2. **¿Hubo algo que casi funcionó?** El intento sin conclusión, el archivado razonable pero
   equivocado, la herramienta que hizo algo parecido a lo pedido. **Es la pregunta que nadie contesta
   sola**: cuando el agente no hace nada se nota en el momento; cuando hace algo casi bien, no lo
   reporta nadie. Va a los aprendizajes marcado `provisional`.

No se inventa material para llenar el archivo. Si la sesión no dejó nada de una clase, esa clase no
tiene línea.

## Cómo se corre

Escribís el material con lo que salió de las dos preguntas —una clave por línea— y corrés:

```
.os/core/lib/close-session.sh --brain . --org <slug> --material <archivo>
```

```
decision:     Título
que:          Qué se decide
porque:       Por qué
reemplaza:    Qué decisión reemplaza          (opcional)
invalidaria:  Qué la haría falsa              (opcional)
learning:     Título
cuerpo:       El cuerpo
provisional:  Título
cuerpo:       El cuerpo
pending:      Texto de la tarea
pending-de:   iniciativa | Texto de la tarea
waiting:      iniciativa | quién destraba
sin-fila:     destino | contenido que archivaste ahí
no-capturado: Lo que no pudiste archivar, y por qué
retomar:      Por dónde sigue la próxima sesión
```

**El texto del operador va siempre al final de su línea y se archiva entero.** Después de la clave
hay a lo sumo un dato estructural —una iniciativa, una ruta— y termina en `|`; lo que sigue es texto
libre y se queda con todo el resto, pipes incluidos. **Nunca lo partas vos ni le saques caracteres**:
si una frase trae un `|`, va tal cual. Un registro se cierra cuando empieza el siguiente.

**Todo lo que escribís en el material sale del operador, no de vos.** Una decisión que él no tomó no
es una decisión: es una inferencia, y va como `no-capturado` para que la vea.

`waiting:` se escribe cuando la sesión deja una iniciativa esperando algo — un gate, una persona, un
tercero. El valor dice quién destraba: eso es lo que la pone arriba de todo en el próximo arranque.

## El veredicto

**Se muestra tal como salió.** Las cuatro partes son fijas: capturado, no capturado, fila candidata
y el puntero para retomar. **Nunca se cierra con "listo" a secas**: un cierre que solo dice que
terminó no se distingue de uno que perdió algo.

Si el veredicto ofrece una fila candidata para el resolver, se la mostrás al operador y la escribís
solo si dice que sí. El resolver crece por excepción encontrada; una fila que él no aprobó es una
arista que nadie va a usar.
