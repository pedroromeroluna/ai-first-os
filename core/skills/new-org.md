---
command: new-org
capability: Agregar una organización
---

# new-org — crear una organización

Una organización es el límite de aislamiento: una empresa, un cliente. Crearla el día 40 deja
exactamente el mismo resultado que declararla el día 1.

## La entrevista

Dos preguntas. Nada más.

1. **¿Qué es esta organización?** Qué hace, para quién y cómo gana plata. Tres o cuatro líneas.
2. **¿Qué hacés vos acá?** De la respuesta sale el rol. **El campo lo escribís vos, nunca se lo
   pedís al operador**: él contesta en su idioma —"soy el que decide producto"— y vos lo traducís a
   un slug. Si todavía no se sabe, el campo nace vacío y se completa cuando el dato aparezca.

## Qué escribe

```
.os/core/lib/new-org.sh --brain . --name "<Nombre>" --role "<slug>" --owner "<persona>" \
  [--identity-file <archivo>]
```

Deja `orgs/<slug>/` con `context.md`, `resolver.md` sin filas e `initiatives/` vacío. Nada más: lo
que solo guarda contenido nace con su primer dato.

`--owner` sale del título de `operator.md`: la organización la crea el operador, así que él es el
dueño. Si el brain todavía no lo tiene —o la organización la lleva otra persona— preguntá quién es
y no lo deduzcas. `--role` y `--owner` son obligatorios porque los escribe el comando: el operador
no ve esos campos ni tiene que acordarse de que existen.

La identidad entra por `--identity-file`. Escribila vos con lo que contestó el operador, sin
inventar lo que no dijo: lo que falte va marcado como hueco.

## Al terminar

- Reportá qué quedó creado en resultados: qué se puede escribir ahí y qué contesta cada archivo.
- Si el aviso del tope de identidad aparece, pasalo tal cual: resumir o partir lo elige el operador.
