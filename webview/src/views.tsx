/** @jsx svg */
import { VNode } from "snabbdom";
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { RenderingContext, svg, RectangularNodeView, SEdge, PolylineEdgeView, SGraphView,
         IViewArgs, Hoverable, Selectable, PreRenderedView, SLabel, SLabelView, SCompartment } from "sprotty";
import { injectable } from "inversify";
import { toDegrees, Point } from "sprotty-protocol";
import {
    AssociativeRelationshipEdge,
    EntityNode,
    ERModel,
    HierarchyNode,
    NotationEdge,
    PopupButton,
    RelationshipNode
} from "./model";
import { DiagramTypes, RelationshipTypes, UITypes } from "./utils";


@injectable()
export class ERModelView<IRenderingArgs> extends SGraphView<IRenderingArgs> {

    // @inject(EdgeRouterRegistry) edgeRouterRegistry: EdgeRouterRegistry;

    override render(model: Readonly<ERModel>, context: RenderingContext, args?: IRenderingArgs): VNode {
        // set model name in toolbar
        const menuModelName = document.getElementById(UITypes.MODEL_NAME);
        if (menuModelName) {
            menuModelName.innerText = model.name;
        }
        // set notation option panel
        const notationSelect = document.getElementById(UITypes.NOTATION_SELECT) as HTMLSelectElement;
        if (notationSelect) {
            notationSelect.value = model.notation;
        }
        const edgeRouting = this.edgeRouterRegistry.routeAllChildren(model);
        const transform = `scale(${model.zoom}) translate(${-model.scroll.x},${-model.scroll.y})`;
        return <svg class-sprotty-graph={true}>
            <g transform={transform}>
                {context.renderChildren(model, edgeRouting)}
            </g>
        </svg>;
    }
}

@injectable()
export class EntityNodeView extends RectangularNodeView {
    override render(node: Readonly<EntityNode>, context: RenderingContext): VNode | undefined {
        if (!this.isVisible(node, context)) {
            return undefined;
        }

        // Altura del encabezado de la entidad
        const headerHeight = node.isUml ? 58 : 38;

        const width = Math.max(node.bounds.width, 0);
        const height = Math.max(node.bounds.height, 0);

        // El rombo ocupa prácticamente toda la entidad asociativa
        const associativePaddingX = 3;
        const associativePaddingY = 3;

        const associativeCenterX = width / 2;
        const associativeCenterY = height / 2;

        const associativeDiamondPoints =
            `${associativeCenterX},${associativePaddingY} ` +
            `${width - associativePaddingX},${associativeCenterY} ` +
            `${associativeCenterX},${height - associativePaddingY} ` +
            `${associativePaddingX},${associativeCenterY}`;

        // Compartimento de atributos
        const attributesCompartment =
            node.children[1] as Readonly<SCompartment> | undefined;

        const hasAttributes =
            !!attributesCompartment &&
            attributesCompartment.children.length > 0;

        // Separador entre cabecera y atributos
        const headerSeparator =
            `M 0,${headerHeight} L ${node.bounds.width},${headerHeight}`;

        return (
            <g>
                {node.weak === true && (
                    <rect
                        class-border-weak={true}
                        x="-5"
                        y="-5"
                        rx="5"
                        ry="5"
                        width={node.bounds.width + 10}
                        height={node.bounds.height + 10}
                    />
                )}

                <rect
                    class-sprotty-node={true}
                    class-mouseover={node.hoverFeedback}
                    class-selected={node.selected}
                    x="0"
                    y="0"
                    rx="5"
                    ry="5"
                    width={width}
                    height={height}
                />

                {/* Rombo interior utilizado para representar entidades asociativas */}
                {node.associative === true && (
                    <polygon
                        class-associative-diamond={true}
                        points={associativeDiamondPoints}
                    />
                )}

                {context.renderChildren(node)}

                {hasAttributes && (
                    <path
                        class-comp-separator={true}
                        d={headerSeparator}
                    />
                )}
            </g>
        );
    }
}

@injectable()
export class HierarchyNodeView extends RectangularNodeView {
    override render(
        node: Readonly<HierarchyNode & Hoverable & Selectable>,
        context: RenderingContext
    ): VNode | undefined {
        if (!this.isVisible(node, context)) {
            return undefined;
        }

        const width = Math.max(node.bounds.width, 0);
        const height = Math.max(node.bounds.height, 0);

        const label = node.children?.[0] as Readonly<SLabel> | undefined;
        const text = label?.text ?? "";

        return (
            <g>
                <rect
                    class-sprotty-node={true}
                    class-hierarchy-node={true}
                    class-mouseover={node.hoverFeedback}
                    class-selected={node.selected}
                    x="0"
                    y="0"
                    rx="5"
                    ry="5"
                    width={width}
                    height={height}
                />

                <text
                    class-hierarchy-label={true}
                    x={width / 2}
                    y={height / 2}
                    text-anchor="middle"
                    dominant-baseline="middle"
                >
                    {text}
                </text>
            </g>
        );
    }
}

/**
 * Renderiza los atributos marcados como UNIQUE.
 *
 * Se reutiliza el renderizado estándar de Sprotty para mostrar el texto
 * y se añade una línea discontinua debajo mediante un elemento SVG
 */
@injectable()
export class UniqueLabelView extends SLabelView {
    override render(
        label: Readonly<SLabel>,
        context: RenderingContext
    ): VNode | undefined {

        // Renderiza primero la etiqueta utilizando el comportamiento estándar
        const renderedLabel = super.render(label, context);

        if (!renderedLabel) {
            return undefined;
        }

        // Calcula la posición vertical y el ancho de la línea discontinua
        // para que coincida con el texto renderizado.
        const underlineY = 3;
        const underlineWidth = label.bounds.width;

        return (
            <g>
                {renderedLabel}

                {/* Línea discontinua utilizada para representar atributos UNIQUE */}
                <line
                    x1={0}
                    y1={underlineY}
                    x2={underlineWidth}
                    y2={underlineY}
                    class-unique-underline={true}
                />
            </g>
        );
    }
}

@injectable()
export class RelationshipNodeView extends RectangularNodeView {

  override render(
    node: Readonly<RelationshipNode & Hoverable & Selectable>,
    context: RenderingContext
  ): VNode | undefined {

    // Si el nodo no es visible, no se renderiza nada
    if (!this.isVisible(node, context)) return undefined;

    // Tamaño del nodo (viene calculado desde el .xtend)
    const w = Math.max(node.bounds.width, 0);
    const h = Math.max(node.bounds.height, 0);

    // Centro del nodo (se usa para dibujar el rombo y centrar textos)
    const cx = w / 2;
    const cy = h / 2;

    // ---- ROMBO ----
    // Puntos del polígono en forma de rombo (arriba, derecha, abajo, izquierda)
    const points = `${cx},0 ${w},${cy} ${cx},${h} 0,${cy}`;

    // ---- TEXTOS DESDE EL MODELO ----
    // Título (nombre de la relación): node.children[0]
    const headerComp: any = node.children?.[0];
    const headerLabel: any = headerComp?.children?.[0];
    const title: string = headerLabel?.text ?? "";

    // Botón de expandir/colapsar del header
    const expandButton: any = headerComp?.children?.[1];

    // Atributos: node.children[1] (cada hijo es una línea)
    const attrsComp: any = node.children?.[1];
    const attrLabels: any[] = (attrsComp?.children ?? []);
    const attrLines: string[] = attrLabels
      .map(l => l?.text)
      .filter((t: any) => typeof t === "string" && t.trim().length > 0);

    // Si hay atributos, se dibuja separador y lista de líneas
    const hasAttrs = attrLines.length > 0;

    // ---- MÉTRICAS VISUALES (espaciados) ----
    // Afecta a TÍTULO / ATRIBUTOS / SEPARADOR (posiciones y separación)
    const titleFont = 18;
    const attrFont = 14;

    const gapTitleToSep = 14; // espacio TÍTULO -> SEPARADOR
    const gapSepToAttrs = 8; // espacio SEPARADOR -> ATRIBUTOS (más pequeño = atributos más arriba)
    const attrLineH = 22; // separación entre líneas de ATRIBUTOS

    const innerPadX = 0; // margen para recortar el SEPARADOR (que no toque el borde del rombo)      // margen para recortar el SEPARADOR (que no toque el borde del rombo)

    // Devuelve la mitad del ancho disponible del rombo a una Y absoluta
    // Se usa para RECORTAR el SEPARADOR según el “estrechamiento” del rombo
    const halfWidthAtY = (yAbs: number) => {
      if (yAbs <= cy) return (w * yAbs) / h;
      return (w * (h - yAbs)) / h;
    };

    // ---- CENTRADO DEL BLOQUE ----
    // blockH = altura del contenido interno (título + separador + atributos)
    // top = desplazamiento para centrar ese contenido dentro del rombo
    const attrsBlockH = hasAttrs ?
        gapTitleToSep + gapSepToAttrs + (attrLines.length * attrLineH) :
        0;

    const blockH = titleFont + attrsBlockH;

    const top = (h - blockH) / 2;

    // ---- POSICIONES RELATIVAS DENTRO DEL BLOQUE ----
    // SOLO movemos el TÍTULO con offset; separador y atributos quedan fijos
    const titleYRelBase = titleFont / 2;
    const titleOffsetY = 6; // mueve SOLO el TÍTULO (más = más abajo)
    const titleYRel = titleYRelBase + titleOffsetY;

    const sepYRel = titleFont + gapTitleToSep; // Y del SEPARADOR (no depende del offset del título)
    const attrsStartYRel =
        titleFont +
        gapTitleToSep +
        gapSepToAttrs +
        (attrLineH / 2); // inicio ATRIBUTOS

    // ---- SEPARADOR (línea) ----
    // Se recorta según el ancho disponible del rombo en esa altura
    const sepYAbs = top + sepYRel;
    const halfSep = Math.max(0, halfWidthAtY(sepYAbs) - innerPadX);
    const sepPath = `M ${cx - halfSep},${sepYRel} L ${cx + halfSep},${sepYRel}`;

    // Atributos comunes de texto: centrado horizontal y vertical
    const mkTextAttrs = (x: number, y: number) => ({
      x: Number(x),
      y: Number(y),
      "text-anchor": "middle",
      "dominant-baseline": "middle"
    }) as any;

    return (
      <g class-relationship={true}>

        {/* ROMBO */}
        <polygon
          class-sprotty-node={true}
          class-mouseover={node.hoverFeedback}
          class-selected={node.selected}
          points={points}
        />

        {/* Contenido centrado dentro del rombo */}
        <g transform={`translate(0,${top})`}>

          {/* TÍTULO (se puede ajustar con titleOffsetY) */}
          <text
            key={`${node.id}-title`}
            attrs={mkTextAttrs(cx, titleYRel)}
            style={{
              pointerEvents: "none",
              fontSize: `${titleFont}px`,
              fontWeight: "bold"
            }}
          >
            {title}
          </text>

        {/* Flecha de expandir/colapsar centrada encima del título */}
        {expandButton && (
            <g transform={`translate(${cx - 8}, ${titleYRel - 23})`}>
                {context.renderElement(expandButton)}
            </g>
        )}

          {/* SEPARADOR (solo visible si la relación está expandida y tiene atributos) */}
          {hasAttrs && node.expanded && (
            <path
              key={`${node.id}-sep`}
              class-comp-separator={true}
              d={sepPath}
              style={{ pointerEvents: "none" }}
            />
          )}

          {/* ATRIBUTOS (cada línea se coloca con attrsStartYRel + i*attrLineH) */}
          {/* (solo visibles si la relación está expandida) */}
          {hasAttrs && node.expanded && attrLines.map((line, i) => {
            const yRel = Number(attrsStartYRel + (i * attrLineH));

            return (
              <text
                key={`${node.id}-attr-${i}`}
                attrs={mkTextAttrs(cx, yRel)}
                style={{
                  pointerEvents: "none",
                  fontSize: `${attrFont}px`
                }}
              >
                {line}
              </text>
            );
          })}

        </g>
      </g>
    );
  }
}

/**
 * Renderiza la punta de flecha utilizada en las jerarquías de herencia.
 *
 * Se añade una clase CSS específica para que la flecha de herencia pueda
 * utilizar un color diferente al de las relaciones normales y adaptarse
 * al tema activo de VS Code.
 */
@injectable()
export class InheritanceEdgeView extends PolylineEdgeView {
    override renderAdditionals(
        edge: SEdge,
        segments: Point[],
        context: RenderingContext
    ): VNode[] {
        // Evita acceder a puntos inexistentes cuando la ruta no contiene suficientes segmentos
        if (segments.length < 2) {
            return [];
        }

        const p1 = segments[segments.length - 2];
        const p2 = segments[segments.length - 1];

        // Dibuja la punta de flecha al final de la ruta y le asigna la clase de herencia
        return [
            <path
                class-sprotty-edge-arrow={true}
                class-inheritance-edge-arrow={true}
                d="M 6,-3 L 0,0 L 6,3 Z"
                transform={`rotate(${angle(p2, p1)} ${p2.x} ${p2.y}) translate(${p2.x} ${p2.y})`}
            />
        ];
    }
}

export function angle(x0: Point, x1: Point): number {
    return toDegrees(Math.atan2(x1.y - x0.y, x1.x - x0.x));
}

@injectable()
export class PopupButtonView extends PreRenderedView {
    override render(model: Readonly<PopupButton>, context: RenderingContext): VNode | undefined {
        const node = super.render(model, context);
        return node;
    }
}



/**
 * Renderiza las aristas correspondientes a las relaciones normales.
 *
 * Se añade una clase CSS específica al contenedor de la arista para
 * poder aplicar un color distinto al utilizado por las jerarquías.
 */
@injectable()
export class NotationEdgeView extends PolylineEdgeView {
    override render(edge: Readonly<NotationEdge>, context: RenderingContext, args?: IViewArgs): VNode | undefined {
        const route = this.edgeRouterRegistry.route(edge, { args });
        if (route.length === 0) {
            if (edge.children.length === 0) {
                return undefined;
            }
            return <g>{context.renderChildren(edge, { route })}</g>;
        }
        if (!this.isVisible(edge, route, context)) {
            if (edge.children.length === 0) {
                return undefined;
            }
            return <g>{context.renderChildren(edge, { route })}</g>;
        }

        // La clase relationship-edge permite diferenciar visualmente
        // las relaciones normales de las aristas de herencia
        return (
            <g
                class-sprotty-edge={true}
                class-relationship-edge={true}
                class-mouseover={edge.hoverFeedback}
            >
                {this.renderLine(edge, route, context, args)}
                {this.renderAdditionals(edge, route, context)}
                {context.renderChildren(edge, { route })}
            </g>
        );
    }

    override renderAdditionals(edge: NotationEdge, segments: Point[], context: RenderingContext): VNode[] {
        const source = segments[0];
        const target = segments[segments.length - 1];
        const penultimateElem = segments[segments.length - 2];
        const secondElem = segments[1];
        switch (edge.notation) {
            case DiagramTypes.BACHMAN_NOTATION: {
                return this.createBachmanEdge(source, target, secondElem, penultimateElem, edge.connectivity, edge.isSource);
            }
            case DiagramTypes.CROWSFOOT_NOTATION: {
                return this.createCrowsFootEdge(source, target, secondElem, penultimateElem, edge.connectivity, edge.isSource);
            }
            case DiagramTypes.UML: {
                if (edge.relationshipType !== null && edge.relationshipType !== RelationshipTypes.DEFAULT) {
                    return this.createUmlEdge(source, target, edge.relationshipType, secondElem, penultimateElem, edge.isSource);
                }
                return [];
            }
            default: {
                // no additional renderings for other notations
                return [];
            }
        }
    }

    private createUmlEdge(point:Point, next:Point, relationshipType:number, secondElem: Point, penultimateElem: Point, isSource: boolean):VNode[] {
        const color = (relationshipType === RelationshipTypes.AGGREGATION_LEFT || relationshipType === RelationshipTypes.AGGREGATION_RIGHT) ? "var(--vscode-editor-background)" : "var(--vscode-editorActiveLineNumber-foreground)";
        // source and target are required for the rotation
        let source = point;
        let target = secondElem;
        if (relationshipType === RelationshipTypes.AGGREGATION_RIGHT || relationshipType === RelationshipTypes.COMPOSITION_RIGHT) {
            source = next;
            target = penultimateElem;
        }
        const polygonPoints = (source.x + 2) + " " + source.y + "," + (source.x + 17) + " " + (source.y - 8) + "," + (source.x + 32) + " " + source.y + "," + (source.x + 17) + " " + (source.y + 8);
        return [<g>
            <polygon points={polygonPoints} fill={color} transform={`rotate(${this.angle(source, target)} ${source.x} ${source.y})`}/>
        </g>];
    }

    protected createCrowsFootEdge(source: Point, target: Point, secondElem: Point, penultimateElem: Point, cardinality: string, isSource: boolean): VNode[] {
        let arrowSourceX = source.x;
        let arrowTargetX = target.x;
        // Move arrow from center of the circle
        if (!isNaN(arrowSourceX)) {
            arrowSourceX = arrowSourceX + 9;
        }
        if (!isNaN(arrowTargetX)) {
            arrowTargetX = arrowTargetX + 9;
        }
        if (cardinality === '0..1') {
            if (isSource) {
                return this.createCrowsFootZeroOrOne(source, secondElem, arrowSourceX);
            }
            return this.createCrowsFootZeroOrOne(target, penultimateElem, arrowTargetX);
        } else if (cardinality === '1' || cardinality === '1..1') {
            if (isSource) {
                return this.createCrowsFootOne(source, secondElem, arrowSourceX);
            }
            return this.createCrowsFootOne(target, penultimateElem, arrowTargetX);
        } else if (cardinality === '0..N') {
            if (isSource) {
                return this.createCrowsFootZeroOrMany(source, secondElem, arrowSourceX);
            }
            return this.createCrowsFootZeroOrMany(target, penultimateElem, arrowTargetX);
        } else if (cardinality === 'N' || cardinality === '1..N') {
            if (isSource) {
                return this.createCrowsFootMany(source, secondElem, arrowSourceX);
            }
            return this.createCrowsFootMany(target, penultimateElem, arrowTargetX);
        } else {
            return [];
        }
    }

    protected createBachmanEdge(source: Point, target: Point, secondElem: Point, penultimateElem: Point, cardinality: string, isSource:boolean): VNode[] {
        let arrowSourceX = source.x;
        let arrowTargetX = target.x;
        // Move arrow from center of the circle
        if (!isNaN(arrowSourceX)) {
            arrowSourceX = arrowSourceX + 9;
        }
        if (!isNaN(arrowTargetX)) {
            arrowTargetX = arrowTargetX + 9;
        }
        if (cardinality === '0..1' || cardinality === '1') {
            const color = cardinality === '0..1' ? "var(--vscode-editor-background)" : "var(--vscode-editorActiveLineNumber-foreground)";
            if (isSource) {
                return this.createEdgeWithCircle(color, source);
            }
            return this.createEdgeWithCircle(color, target);
        } else if (cardinality === '0..N' || cardinality === 'N') {
            const color = cardinality === '0..N' ? "var(--vscode-editor-background)" : "var(--vscode-editorActiveLineNumber-foreground)";
            if (isSource) {
                return this.createEdgeWithCircleAndArrow(color, source, secondElem, arrowSourceX);
            }
            return this.createEdgeWithCircleAndArrow(color, target, penultimateElem, arrowTargetX);
        } else {
            return [];
        }
    }

    private createEdgeWithCircle(color: string, point: Point): VNode[] {
        return [<g>
                <circle cx={point.x} cy={point.y} r="7" stroke-width="1" fill={color}/>
            </g>
        ];
    }

    private createEdgeWithCircleAndArrow(color: string, point: Point, next: Point, targetX: number): VNode[] {
        return [
            <g>
                <circle cx={point.x} cy={point.y} r="7" stroke-width="1" fill={color}/>
                <path class-sprotty-edge-arrow={true} d="M 7,-4 L 0,0 L 7,4 Z"
                    transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y}) translate(${targetX} ${point.y})`}/>
            </g>
        ];
    }

    private createCrowsFootZeroOrOne(point: Point, next: Point, targetX: number): VNode[] {
        return [<g>
            <circle cx={point.x + 25} cy={point.y} r="7" stroke-width="1" fill="var(--vscode-editor-background)"
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 10} y1={point.y + 11} x2={point.x + 10} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
        </g>];
    }

    private createCrowsFootZeroOrMany(point: Point, next: Point, targetX: number): VNode[] {
        return [<g>
            <circle cx={point.x + 26} cy={point.y} r="7" stroke-width="1" fill="var(--vscode-editor-background)"
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 17} y1={point.y} x2={point.x} y2={point.y + 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 17} y1={point.y} x2={point.x} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
        </g>];
    }

    private createCrowsFootOne(point: Point, next: Point, targetX: number): VNode[] {
        return [<g>
            <line x1={point.x + 19} y1={point.y + 11} x2={point.x + 19} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 10} y1={point.y + 11} x2={point.x + 10} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
        </g>];
    }

    private createCrowsFootMany(point: Point, next: Point, targetX: number): VNode[] {
        return [<g>
            <line x1={point.x + 24} y1={point.y + 11} x2={point.x + 24} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 17} y1={point.y} x2={point.x} y2={point.y + 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
            <line x1={point.x + 17} y1={point.y} x2={point.x} y2={point.y - 11}
                transform={`rotate(${this.angle(point, next)} ${point.x} ${point.y})`}/>
        </g>];
    }

    angle(x0: Point, x1: Point): number {
        return toDegrees(Math.atan2(x1.y - x0.y, x1.x - x0.x));
    }
}

/**
 * Renderiza las aristas correspondientes a las relaciones asociativas.
 *
 * Una relación asociativa se representa mediante una línea directa
 * y continua entre las entidades participantes, sin nodo intermedio
 * ni nombre de relación.
 *
 * Las cardinalidades se renderizan como etiquetas sobre la propia arista.
 */
@injectable()
export class AssociativeRelationshipEdgeView extends NotationEdgeView {
    override render(
        edge: Readonly<AssociativeRelationshipEdge>,
        context: RenderingContext,
        args?: IViewArgs
    ): VNode | undefined {
        const route = this.edgeRouterRegistry.route(edge, { args });

        if (route.length === 0 || !this.isVisible(edge, route, context)) {
            if (edge.children.length === 0) {
                return undefined;
            }
            return <g>{context.renderChildren(edge, { route })}</g>;
        }

        return (
            <g
                class-sprotty-edge={true}
                class-associative-relationship-edge={true}
                class-mouseover={edge.hoverFeedback}
            >
                {this.renderLine(edge, route, context, args)}
                {this.renderAssociativeMarkers(edge, route)}
                {context.renderChildren(edge, { route })}
            </g>
        );
    }

    // Dos extremos con cardinalidades distintas, asi que se dibuja una
    // marca en cada uno. Anadir una notacion nueva es anadir un case.
    private renderAssociativeMarkers(
        edge: Readonly<AssociativeRelationshipEdge>,
        segments: Point[]
    ): VNode[] {
        const source = segments[0];
        const target = segments[segments.length - 1];
        const secondElem = segments[1];
        const penultimateElem = segments[segments.length - 2];

        const markersFor = (cardinality: string, isSource: boolean): VNode[] => {
            switch (edge.notation) {
                case DiagramTypes.CROWSFOOT_NOTATION:
                    return this.createCrowsFootEdge(source, target, secondElem, penultimateElem, cardinality, isSource);
                case DiagramTypes.BACHMAN_NOTATION:
                    return this.createBachmanEdge(source, target, secondElem, penultimateElem, cardinality, isSource);
                default:
                    return [];
            }
        };

        return [
            ...markersFor(edge.sourceConnectivity, true),
            ...markersFor(edge.targetConnectivity, false)
        ];
    }
}