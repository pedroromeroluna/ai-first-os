---
command: bootstrap
capability: Crear el brain desde cero
handoff: Agregar una organización
---

# bootstrap — crear el brain

Entrevistá al operador y creá el brain mínimo. No preguntes alcance: la capa de construcción se
activa por iniciativa, no por usuario.

## La entrevista

Cinco preguntas. Una por vez, y no sigas hasta tener la respuesta.

1. **¿Cómo te llamás?**
2. **Perfil**: a qué te dedicás, en qué estás hoy, qué decidís vos.
3. **Voz**: cómo escribís cuando escribís bien — idioma, registro, qué palabras no usás.
4. **Cómo se te contesta**: qué esperás de un agente. Largo, orden, qué te molesta.
5. **Tus organizaciones**: dónde trabajás. Para el caso típico —una persona, un empleador— es una.
   Para cada una preguntá **qué hace** y **qué hacés vos ahí**; el rol lo escribe el sistema.

Devolvé las respuestas resumidas y esperá el visto bueno antes de escribir nada.

## Qué escribe

Armá un archivo de respuestas y corré la parte determinística:

```
.os/core/lib/bootstrap.sh --brain . --answers <archivo>
```

Formato del archivo de respuestas, una clave por línea:

```
name: <nombre>
profile: <un ítem>
voice: <un ítem>
reply: <un ítem>
org: <Nombre> | <rol> | <dueño> | <archivo de identidad>
```

`profile`, `voice`, `reply` y `org` se repiten. En `org`, el dueño y el archivo de identidad son
opcionales: sin dueño queda el operador, y sin identidad queda el texto a completar.

El resultado son `operator.md`, `voice.md`, `resolver.md`, `tree.md` y una carpeta por
organización. `voice.md` es la voz del operador — antes vivía en una sección de `operator.md`, y
desde ahora es su propio archivo: una identidad, dos preguntas, nunca la misma frase en las dos.
Nada más: el inbox, el trabajo propio de la raíz (iniciativas, backlog, decisiones, aprendizajes) y
la tabla del entorno nacen con su primer dato, como cualquier nodo.

**Corre una sola vez por brain.** Si las piezas de la raíz ya están, el script frena en vez de
reescribirlas. Sumar una organización a un brain que ya existe es trabajo de `new-org`.

## Al terminar

- Mostrá el árbol creado y qué contesta cada archivo, en resultados y no en nombres canónicos.
- Si el aviso del tope de identidad aparece, pasalo tal cual: la salida la elige el operador.
- Si el script declara `sin dato:` o `sin crear:`, pasalo entero y volvé a preguntar lo que falta.
  Un hueco que no se nombra es un hueco que nadie completa.
- Handoff: si el operador quiere sumar otra organización, hace falta la capacidad **agregar una
  organización**. Si no está disponible, decilo y seguí.
