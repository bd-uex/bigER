package org.big.erd.ide.diagram
import com.google.inject.Inject
import org.big.erd.entityRelationship.Entity
import org.big.erd.entityRelationship.Attribute
import org.big.erd.entityRelationship.AttributeType
import org.big.erd.entityRelationship.VisibilityType
import org.big.erd.entityRelationship.EntityRelationshipPackage
import org.big.erd.entityRelationship.Relationship
import org.big.erd.entityRelationship.RelationEntity
import org.big.erd.entityRelationship.Model
import org.big.erd.ide.diagram.EntityNode
import org.big.erd.ide.diagram.NotationEdge
import org.big.erd.ide.diagram.RelationshipNode
import org.big.erd.ide.diagram.AssociativeRelationshipEdge
import org.eclipse.sprotty.Dimension
import org.big.erd.ide.diagram.ERModel
import org.eclipse.emf.ecore.EObject
import org.eclipse.sprotty.SEdge
import org.eclipse.sprotty.SModelElement
import org.eclipse.sprotty.SButton
import org.eclipse.sprotty.LayoutOptions
import org.eclipse.sprotty.SLabel
import java.util.ArrayList
import java.util.List
import org.eclipse.sprotty.xtext.IDiagramGenerator
import org.apache.log4j.Logger
import org.eclipse.sprotty.IDiagramState
import org.eclipse.sprotty.xtext.tracing.ITraceProvider
import org.eclipse.sprotty.xtext.SIssueMarkerDecorator
import org.eclipse.sprotty.SCompartment
import org.big.erd.entityRelationship.CardinalityType
import org.big.erd.entityRelationship.NotationType
import org.big.erd.entityRelationship.RelationshipType
import org.big.erd.entityRelationship.Hierarchy
import org.big.erd.ide.diagram.HierarchyNode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import static org.big.erd.entityRelationship.EntityRelationshipPackage.Literals.*


class ERDiagramGenerator implements IDiagramGenerator {

	static val LOG = Logger.getLogger(ERDiagramGenerator)

	@Inject extension ITraceProvider
	@Inject extension SIssueMarkerDecorator

	IDiagramState state
	Model model

	override generate(Context context) {
		this.state = context.state
		val contentHead = context.resource.contents.head
		if (contentHead instanceof Model) {
			LOG.debug("Generating diagram for model with URI '" + context.resource.URI.lastSegment + "'")
			model = contentHead
			toSGraph(contentHead, context)
		}
	}

	def ERModel toSGraph(Model m, extension Context context) {
		val notationType = m.notation?.notationType ?: NotationType.DEFAULT
		val graph = new ERModel => [
			id = idCache.uniqueId(m, 'root')
			type = DiagramTypes.GRAPH
			name = m.name
			notation = notationType.toString
			children = new ArrayList<SModelElement>
		]

		// Create entity nodes
		graph.children.addAll(m.entities.map[toSNode(context)])

		// Create hierarchy nodes and edges
		graph.children.addAll(m.hierarchies.map[toHierarchyNode(context)])
		m.hierarchies.forEach[
			graph.children.addAll(hierarchyEdges(it, context))
		]
	
		// Create relationship nodes and edges
		m.relationships.forEach[
			if (it.associative) {
				// Associative relationships are represented as direct edges
				// between the participating entities, without a relationship node.
				graph.children.addAll(addAssociativeRelationEdges(it, context))
			} else {
				// Standard relationships keep their existing representation.
				if (!notationType.equals(NotationType.UML)) {
					graph.children.add(relationshipNodes(it, context))
				} else if (notationType.equals(NotationType.UML) && it.third !== null) {
					graph.children.add(relationshipNodes(it, context))
				}

				graph.children.addAll(addRelationEdges(it, context))
			}
		]
		graph.traceAndMark(m, context)
		return graph;
	}

	// Calcula cuánto ancho útil céntrico tiene el rombo a cierta altura (dy)
	// Afecta al tamaño final del ROMBO para que el texto no se salga
	def double widthFactor(double dy, double diamondH) {
		val f = 1.0 - (2.0 * Math.abs(dy) / diamondH)
		return Math.max(0.35, f)
	}

	// Estima el ancho necesario para una línea de texto
	// Se usa para calcular el ancho mínimo del ROMBO
	def double reqLineW(String s, double charW, double padX) {
		val int l = if (s === null) 0 else s.length
		return (l as double) * charW + 2.0 * padX
	}

	def RelationshipNode relationshipNodes(Relationship relationship, extension Context context) {

		val relationshipId = idCache.uniqueId(relationship, relationship.name)

		// Estado expandido/colapsado de la relación
		val isExpanded = state.expandedElements.contains(relationshipId) || state.currentModel.type == 'NONE'

		// ---- Textos ----
		// Título del rombo
		val headerText = relationship.name ?: ""

		// Líneas de atributos solo si la relación está expandida
		val attrLines = if (isExpanded)
			relationship.attributes?.map[a |
				a.name + " " + attributeDatatypeString(a)
			] ?: newArrayList
		else
			newArrayList

		val hasAttrs = !attrLines.empty

		// ---- Métricas visuales ----
		val double charW = 7.0
		val double padX = 24.0
		val double padTipY = 18.0

		val double titleFont = 18.0
		val double gapTitleToSep = 10.0     // espacio título -> separador
		val double gapSepToAttrs = 12.0     // espacio separador -> atributos
		val double attrLineH = 18.0         // separación entre atributos

		// Altura del contenido interno (título + separador + atributos)
		// Afecta a la altura final del ROMBO
		val double blockH =
			titleFont +
			(if (hasAttrs) (gapTitleToSep + gapSepToAttrs + attrLines.size * attrLineH) else 0.0)

		// Altura del rombo según contenido
		val double diamondH = Math.max(90.0, blockH + 2.0 * padTipY)
		val double cy = diamondH / 2.0

		// Posiciones relativas del bloque interno
		val double titleYRel = titleFont / 2.0         // centro del título
		val double sepYRel = titleFont + gapTitleToSep // posición del separador

		// Calcula el rango vertical del contenido para centrarlo en el rombo
		val double firstRel = titleYRel
		val double lastRel = if (hasAttrs)
			(sepYRel + gapSepToAttrs + attrLineH / 2.0 + (attrLines.size - 1) * attrLineH)
		else
			titleYRel

		// Desplazamiento para centrar el bloque (título + atributos) en el rombo
		val double shiftY = cy - ((firstRel + lastRel) / 2.0)

		val double titleY = titleYRel + shiftY

		// ---- Cálculo del ancho mínimo del rombo ----
		var double requiredW = 120.0

		// Título influye en el ancho necesario del rombo
		val double dyTitle = titleY - cy
		val double needTitleW = reqLineW(headerText, charW, padX) / widthFactor(dyTitle, diamondH)
		requiredW = Math.max(requiredW, needTitleW)

		// Atributos también influyen en el ancho del rombo
		if (hasAttrs) {
			val double attrsStartY = (sepYRel + gapSepToAttrs + attrLineH / 2.0) + shiftY

			var int i = 0
			for (line : attrLines) {
				val double y = attrsStartY + i * attrLineH
				val double dy = y - cy
				val double needW = reqLineW(line, charW, padX) / widthFactor(dy, diamondH)
				requiredW = Math.max(requiredW, needW)
				i = i + 1
			}
		}

		// Anchura final del ROMBO
		val double diamondW = Math.max(120.0, requiredW + 6.0)

		// ---- Creación del nodo del rombo ----
		val node = new RelationshipNode => [
			id = relationshipId
			type = DiagramTypes.NODE_RELATIONSHIP
			weak = relationship.weak ? true : false

			size = new Dimension(diamondW, diamondH)

			layout = 'vbox'
			layoutOptions = new LayoutOptions [
				minWidth  = diamondW
				minHeight = diamondH
				HAlign = 'center'
				VAlign = 'center'
				VGap = 0.0
				paddingFactor = 0.0
			]

			children = new ArrayList<SModelElement>
		]

		// Compartimento del TÍTULO con botón de expandir/colapsar
		node.children.add(new SCompartment => [
			id = idCache.uniqueId(relationshipId + '.header-comp')
			type = DiagramTypes.COMP_ENTITY_HEADER
			layout = 'hbox'
			children = #[
				(new SLabel [
					id = idCache.uniqueId(relationshipId + '.label')
					type = DiagramTypes.ENTITY_LABEL
					text = relationship.name
				]).trace(relationship, RELATIONSHIP__NAME, -1),
				(new SButton [
					id = idCache.uniqueId(relationshipId + '.button')
					type = DiagramTypes.BUTTON_EXPAND
				])
			]
		])

		// Compartimento de ATRIBUTOS solo se añaden si la relación está expandida
		if (isExpanded) {
			val comp = new SCompartment => [
				id = relationshipId + '.attributes'
				type = DiagramTypes.COMP_ATTRIBUTES
				layout = 'none'
				children = new ArrayList<SModelElement>
			]

			if (relationship.attributes !== null && !relationship.attributes.empty) {
				var int j = 0
				for (a : relationship.attributes) {
					val attrId = idCache.uniqueId(relationshipId + ".attr." + j)
					val attrText = a.name + " " + attributeDatatypeString(a)

					comp.children.add(
						(new SLabel [
							id = attrId
							text = attrText
							type = DiagramTypes.LABEL_TEXT
						]).trace(a, ATTRIBUTE__NAME, -1)
					)
					j = j + 1
				}
			}

			node.children.add(comp)
			state.expandedElements.add(relationshipId)
			node.expanded = true
		} else {
			node.expanded = false
		}

		return node.traceAndMark(relationship, context)
	}

	def List<SModelElement> addAssociativeRelationEdges(
		Relationship relationship,
		extension Context context
	) {
		val edges = new ArrayList<SModelElement>

		if (relationship.first === null || relationship.second === null) {
			return edges
		}

		val notationType = model.notation?.notationType ?: NotationType.DEFAULT

		val source = idCache.getId(relationship.first.target)
		val target = idCache.getId(relationship.second.target)

		val edgeId = idCache.uniqueId(
			relationship,
			source + ":associative:" + relationship.name + ":" + target
		)

		edges.add(
			(new AssociativeRelationshipEdge [
				id = edgeId
				type = DiagramTypes.EDGE_ASSOCIATIVE_RELATIONSHIP
				sourceId = source
				targetId = target
				notation = notationType.toString
				sourceConnectivity = getCardinality(relationship.first)
				targetConnectivity = getCardinality(relationship.second)
				children = createAssociativeRelationshipLabels(
					relationship.first,
					relationship.second,
					notationType,
					edgeId,
					context
				)
			]).traceAndMark(relationship, context)
		)

		return edges
	}

	def SLabel[] createAssociativeRelationshipLabels(
		RelationEntity sourceRelation,
		RelationEntity targetRelation,
		NotationType notation,
		String edgeId,
		extension Context context
	) {
		// En crowsfoot la cardinalidad va en las marcas gráficas de la
		// propia arista, no en etiquetas de texto
		if (usesGraphicalCardinality(notation)) {
			return newArrayOfSize(0)
		}

		val SLabel[] labels = newArrayOfSize(2)


		labels.set(0, (new SLabel [
			id = idCache.uniqueId(edgeId + '.sourceCardinality')
			text = getAssociativeCardinality(sourceRelation)
			type = DiagramTypes.LABEL_TOP_LEFT
		]).trace(sourceRelation, RELATION_ENTITY__CARDINALITY, -1))

		labels.set(1, (new SLabel [
			id = idCache.uniqueId(edgeId + '.targetCardinality')
			text = getAssociativeCardinality(targetRelation)
			type = DiagramTypes.LABEL_TOP_RIGHT
		]).trace(targetRelation, RELATION_ENTITY__CARDINALITY, -1))

		return labels
	}
	
	def List<SModelElement> addRelationEdges(Relationship rel, extension Context context) {
		val edges = new ArrayList<SModelElement>

		if (model.notation !== null && model.notation?.notationType.equals(NotationType.UML) && rel.third === null) {
			val source = idCache.getId(rel.first.target)
			val target = idCache.getId(rel.second.target)
			val relationshipType = rel.firstType.value
			edges.add(createEdgeAndAddToGraph(rel.first, rel.second, source, target, relationshipType, context))
			return edges
		}
		// for each RelationEntity create an edge that connects the entity with the relationship node
		if (rel.first !== null) {
			var relationshipType = 0;
			if(rel.firstType.equals(RelationshipType.AGGREGATION_LEFT) || rel.firstType.equals(RelationshipType.COMPOSITION_LEFT)) {
				relationshipType = rel.firstType.value
			}
			val source = idCache.getId(rel.first.target)
			val target = idCache.getId(rel)
			edges.add(createEdgeAndAddToGraph(rel.first, null, source, target, relationshipType, context))
		} 
		if (rel.second !== null) {
			var relationshipType = 0;
			if(rel.firstType.equals(RelationshipType.AGGREGATION_RIGHT) || rel.firstType.equals(RelationshipType.COMPOSITION_RIGHT)) {
				relationshipType = rel.firstType.value
			}
			if(rel.secondType.equals(RelationshipType.AGGREGATION_LEFT) || rel.secondType.equals(RelationshipType.COMPOSITION_LEFT)) {
				// +1 to change the aggregation type from left to right
				relationshipType = rel.secondType.value + 1
			}
			val source = idCache.getId(rel)
			val target = idCache.getId(rel.second.target)
			edges.add(createEdgeAndAddToGraph(rel.second, null, source, target, relationshipType, context))
		} 
		if (rel.third !== null) {
			var relationshipType = 0;
			if(rel.secondType.equals(RelationshipType.AGGREGATION_RIGHT) || rel.secondType.equals(RelationshipType.COMPOSITION_RIGHT)) {
				relationshipType = rel.secondType.value
			}
			val source = idCache.getId(rel)
			val target = idCache.getId(rel.third.target)
			edges.add(createEdgeAndAddToGraph(rel.third, null, source, target, relationshipType, context))
		}
		return edges
	}

	def NotationEdge createEdgeAndAddToGraph(RelationEntity relation, RelationEntity targetRelation, String source, String target, Integer relType, extension Context context) {
		val notationType = model.notation?.notationType ?: NotationType.DEFAULT
		val relationship = relation.eContainer() as Relationship;
		val edgeId = idCache.uniqueId(relation, source + ":" + relationship.name + ":" + target)

		return (new NotationEdge [
			id = edgeId
			type = getEdgeType(relation, notationType)
			sourceId = source
			targetId = target
			notation = notationType.toString
			connectivity = getCardinality(relation)
			isSource = relation.equals(relationship.first)
			relationshipType = relType 
			children = createLabels(relation, targetRelation, notationType, edgeId, context)
		]).traceAndMark(relation, context)
	}
	
	def SLabel[] createLabels(
		RelationEntity relation,
		RelationEntity targetRelation,
		NotationType notation,
		String edgeId,
		extension Context context
	) {
		val typeCardinality = targetRelation === null ?
			DiagramTypes.LABEL_TOP :
			DiagramTypes.LABEL_TOP_LEFT
		val typeRole = targetRelation === null ?
			DiagramTypes.LABEL_BOTTOM :
			DiagramTypes.LABEL_BOTTOM_LEFT

		// Sin indices fijos: cada etiqueta se anade cuando corresponde, asi
		// anadir o quitar una no obliga a renumerar las demas
		val labels = new ArrayList<SLabel>

		labels.add((new SLabel [
			id = idCache.uniqueId(edgeId + '.label')
			text = getEdgeLabelText(notation, getCardinality(relation))
			type = typeCardinality
		]).trace(relation, RELATION_ENTITY__CARDINALITY, -1))

		labels.add((new SLabel [
			id = idCache.uniqueId(edgeId + '.roleLabel')
			text = getRoleLabelText(relation)
			type = typeRole
		]).trace(relation, RELATION_ENTITY__ROLE, -1))

		if (targetRelation !== null) {
			val relationship = relation.eContainer() as Relationship

			labels.add((new SLabel [
				id = idCache.uniqueId(edgeId + '.relationName')
				text = relationship.name
				type = DiagramTypes.LABEL_TOP
			]).trace(relationship, RELATIONSHIP__NAME, -1))

			labels.add((new SLabel [
				id = idCache.uniqueId(edgeId + '.additionalLabel')
				text = getEdgeLabelText(notation, getCardinality(targetRelation))
				type = DiagramTypes.LABEL_TOP_RIGHT
			]).trace(targetRelation, RELATION_ENTITY__CARDINALITY, -1))

			labels.add((new SLabel [
				id = idCache.uniqueId(edgeId + '.additionalRoleLabel')
				text = getRoleLabelText(targetRelation)
				type = DiagramTypes.LABEL_BOTTOM_RIGHT
			]).trace(targetRelation, RELATION_ENTITY__ROLE, -1))
		}

		return labels
	}

	def EntityNode toSNode(Entity e, extension Context context) {
		val entityId = idCache.uniqueId(e, e.name)

		val node = new EntityNode [
			id = entityId
			type = DiagramTypes.NODE_ENTITY
			// Propaga al modelo gráfico si la entidad es débil
			weak = e.weak ? true : false
			// Propaga al modelo gráfico si la entidad es asociativa
			associative = e.associative ? true : false

			layout = 'vbox'
			layoutOptions = new LayoutOptions [
				VGap = 10.0
			]
			children = new ArrayList<SModelElement>
		]

		node.children.add(new SCompartment => [
			id = idCache.uniqueId(entityId + '.header-comp')
			type = DiagramTypes.COMP_ENTITY_HEADER
			layout = 'hbox'
			children = #[
				(new SLabel [
					id = idCache.uniqueId(entityId + '.label')
					type = DiagramTypes.ENTITY_LABEL
					text = e.name
				]).trace(e, EntityRelationshipPackage.Literals.ENTITY__NAME, -1),
				(new SButton [
					id = idCache.uniqueId(entityId + '.button')
					type = DiagramTypes.BUTTON_EXPAND
				])
			]
		])

		/* TODO: add for UML Notation
		if (model.notation !== null && model.notation.notationType.equals(NotationType.UML)) {
			node.isUml = true
			headerCompartment.children.add((new SLabel [
					id = idCache.uniqueId(entityId + '.uml-label')
					type = DiagramTypes.LABEL_TEXT
					text = '<<Entity>>'
				]))
		}*/

		// Create attributes if element is expanded
		if (state.expandedElements.contains(entityId) || state.currentModel.type == 'NONE') {
			val comp = new SCompartment => [
				id = entityId + '.attributes'
				type = DiagramTypes.COMP_ATTRIBUTES
				layout = 'vbox'
				layoutOptions = new LayoutOptions [
					// Los atributos de las entidades asociativas se centran dentro del rombo
					HAlign = if (e.associative) 'center' else 'left'
					VGap = 1.0
				]
				children = new ArrayList<SModelElement>
			]

			comp.children.addAll(e.attributes.map[
				createAttributeLabels(entityId, context)
			])

			node.children.add(comp)

			state.expandedElements.add(entityId)
			node.expanded = true
		} else {
			node.expanded = false
		}

		node.traceAndMark(e, context)
		return node
	}

	def HierarchyNode toHierarchyNode(Hierarchy hierarchy, extension Context context) {
		val hierarchyId = idCache.uniqueId(hierarchy, hierarchy.name)

		val hasConstraint = !NodeModelUtils.findNodesForFeature(
			hierarchy,
			HIERARCHY__CONSTRAINT
		).empty

		val hierarchyText =
			if (hasConstraint)
				hierarchy.completeness.toString.toLowerCase + ' ' +
					hierarchy.constraint.toString.toLowerCase
			else
				hierarchy.completeness.toString.toLowerCase

		// Calculate the node width according to the hierarchy text.
		// Extra horizontal padding prevents the label from touching the borders.
		val double charWidth = 7.5
		val double horizontalPadding = 18.0

		val double hierarchyWidth = Math.max(
			90.0,
			hierarchyText.length * charWidth + 2.0 * horizontalPadding
		)

		val double hierarchyHeight = 32.0

		val node = new HierarchyNode => [
			id = hierarchyId
			type = DiagramTypes.NODE_HIERARCHY
			layout = 'hbox'

			size = new Dimension(hierarchyWidth, hierarchyHeight)

			layoutOptions = new LayoutOptions [
				minWidth = hierarchyWidth
				minHeight = hierarchyHeight
				HAlign = 'center'
				VAlign = 'center'
				paddingFactor = 0.0
			]

			children = new ArrayList<SModelElement>
		]

		node.children.add(
			(new SLabel [
				id = idCache.uniqueId(hierarchyId + '.label')
				type = DiagramTypes.LABEL_HIERARCHY
				text = hierarchyText
			]).trace(hierarchy, HIERARCHY__COMPLETENESS, -1)
		)

		return node.traceAndMark(hierarchy, context)
	}

	def SCompartment createAttributeLabels(Attribute a, String entityId, extension Context context) {
		val attributeId = idCache.uniqueId(a, entityId + '.' + a.name)
		val labelType = getAttributeLabelType(a)
		
		return (new SCompartment => [
			id = attributeId
			type = DiagramTypes.COMP_ATTRIBUTE_ROW
			layout = 'hbox'
			layoutOptions = new LayoutOptions [
				VAlign = 'middle'
				HGap = 5.0
			]
			if (model.notation !== null && model.notation?.notationType.equals(NotationType.UML) && !a.visibility.equals(VisibilityType.NONE)) {
				children = #[(new SLabel [
					id = attributeId + '.visibility'
					text = a.visibility.toString
					type = DiagramTypes.LABEL_VISIBILITY
				]),
				(new SLabel [
					id = attributeId + '.name'
					text = a.name
					type = labelType
				]).trace(a, ATTRIBUTE__NAME, -1),
				(new SLabel [
					id = attributeId + ".datatype"
					text = attributeDatatypeString(a)
					type = labelType
				])]
			} else {
				children = #[(new SLabel [
					id = attributeId + '.name'
					text = a.name
					type = labelType
				]).trace(a, ATTRIBUTE__NAME, -1),
				(new SLabel [
					id = attributeId + ".datatype"
					text = attributeDatatypeString(a)
					type = labelType
				])]
			}
		]).traceAndMark(a, context)
	}

	def List<SModelElement> hierarchyEdges(Hierarchy hierarchy, extension Context context) {
		val edges = new ArrayList<SModelElement>

		val hierarchyId = idCache.getId(hierarchy)
		val baseId = idCache.getId(hierarchy.base)

		// Create one edge from the hierarchy node to its superclass
		edges.add(new SEdge [
			sourceId = hierarchyId
			targetId = baseId
			id = idCache.uniqueId(hierarchyId + ':extends:' + baseId)
			type = DiagramTypes.EDGE_INHERITANCE
			children = new ArrayList<SModelElement>
		])

		// Create one edge from each subclass to its hierarchy node
		val subclasses = model.entities.filter[
			it.extends === hierarchy
		]

		for (subclass : subclasses) {
			val subclassId = idCache.getId(subclass)

			edges.add(new SEdge [
				sourceId = subclassId
				targetId = hierarchyId
				id = idCache.uniqueId(
					subclassId + ':extends:' + hierarchyId
				)
				type = DiagramTypes.EDGE_INHERITANCE
				children = new ArrayList<SModelElement>
			])
		}

		return edges
	}
	
	def <T extends SModelElement> T traceAndMark(T sElement, EObject element, Context context) {
		return sElement.trace(element).addIssueMarkers(element, context)
	}

	def String attributeDatatypeString(Attribute a) {
		if (a.datatype !== null) {
			if (a.datatype.size !== 0 && a.datatype.d !== 0) {
				return a.datatype.type + '(' + a.datatype.size + ', ' + a.datatype.d + ')'
			} else if (a.datatype.size !== 0 && a.datatype.d === 0) {
				return a.datatype.type + '(' + a.datatype.size + ')'
			}
			return a.datatype.type
		}
		return ' '
	}
	
	def String getCardinality(RelationEntity relationEntity) {
		if (relationEntity.cardinality !== null && !(relationEntity.cardinality.equals(CardinalityType.NONE))) {
			return relationEntity.cardinality.toString
		}
		return ' '
	}

	def String getAssociativeCardinality(RelationEntity relationEntity) {
		if (relationEntity.cardinality === null) {
			return ' '
		}

		return switch relationEntity.cardinality {
			case CardinalityType.ONE: '1..1'
			case CardinalityType.MANY: '1..N'
			case CardinalityType.ZERO_OR_ONE: '0..1'
			case CardinalityType.ZERO_OR_MORE: '0..N'
			default: ' '
		}
	}
	
	def getEdgeType(RelationEntity relation, NotationType notation) {
		if (notation.equals(NotationType.CHEN)) {
			val cardinality = relation.cardinality ?: CardinalityType.NONE
			if (cardinality === CardinalityType.ZERO_OR_ONE || cardinality === CardinalityType.ZERO_OR_MORE) {
				return DiagramTypes.EDGE_PARTIAL
			}
		}
		return DiagramTypes.EDGE
	}
	

	// Unico sitio donde se decide si una notacion expresa la cardinalidad
	// con marcas graficas sobre la arista o con etiquetas de texto
	def boolean usesGraphicalCardinality(NotationType notation) {
		return notation.equals(NotationType.CROWSFOOT) || notation.equals(NotationType.BACHMAN)
	}

	def String getEdgeLabelText(NotationType notation, String cardinality) {
		if (usesGraphicalCardinality(notation)) {
			return ' '
		}
		return cardinality
	}

	
	def String getRoleLabelText(RelationEntity relation) {
		if (relation.role !== null) {
			return relation.role
		} 
		return ' '
	}
	
	def String getAttributeLabelType(Attribute attribute) {
		return switch attribute.type {
			case AttributeType.KEY: DiagramTypes.LABEL_KEY
			case AttributeType.PARTIAL_KEY: DiagramTypes.LABEL_PARTIAL_KEY
			case AttributeType.DERIVED: DiagramTypes.LABEL_DERIVED
			case AttributeType.UNIQUE: DiagramTypes.LABEL_UNIQUE
			default: DiagramTypes.LABEL_TEXT
		}
	}
}
