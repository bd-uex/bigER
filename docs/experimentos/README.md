# Experimentos descartados

## refactor-layouter.patch

Reescribe `RelationshipNodeView` para que el rombo de relación deje de
posicionar sus hijos a mano y delegue en el layouter de Sprotty, igual
que hacen las entidades. En el servidor elimina el cálculo manual del
tamaño del rombo (`widthFactor`, `reqLineW`, `charW`) y usa la opción
`paddingFactor` de Sprotty, pensada para nodos no rectangulares.

Para un rombo, el valor geométricamente exacto es 2.0: con semiejes a y
b el borde cumple x/a + y/b = 1, así que un rectángulo centrado de W x H
queda inscrito con a = W y b = H.

Probado y funcional. Se descartó porque `paddingFactor` es un único
factor que escala ancho y alto a la vez, de modo que un nombre de
relación largo, que obliga a un rombo ancho, infla también la altura en
la misma proporción. Los rombos quedaban desproporcionados y bajar el
factor a 1.7 apenas lo corregía.

Generado sobre el commit cc34d2b. No aplica limpio sobre el código
actual; queda como referencia, no como parche utilizable.
