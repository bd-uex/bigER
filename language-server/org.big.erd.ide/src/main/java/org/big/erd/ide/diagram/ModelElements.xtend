package org.big.erd.ide.diagram

import org.eclipse.sprotty.SNode
import org.eclipse.sprotty.SEdge
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.sprotty.SGraph
import org.eclipse.sprotty.PreRenderedElement

@Accessors
class ERModel extends SGraph {
	String name
	String notation

	new() { }
	new((ERModel) => void initializer) {
		initializer.apply(this);
	}
}

@Accessors
class EntityNode extends SNode {
	boolean expanded
	// Indica si la entidad debe representarse como entidad débil
	boolean weak
	// Indica si la entidad debe representarse como entidad asociativa
	boolean associative
	boolean isUml

	new() { }
	new((EntityNode) => void initializer) {
		initializer.apply(this)
	}
}

@Accessors
class HierarchyNode extends SNode {

	new() { }
	new((HierarchyNode) => void initializer) {
		initializer.apply(this)
	}
}

@Accessors
class RelationshipNode extends SNode {
	boolean expanded
	boolean weak

	new() { }
	new((RelationshipNode) => void initializer) {
		initializer.apply(this)
	}
}

@Accessors
class NotationEdge extends SEdge {
	Boolean isSource
	String connectivity
	String notation
	Integer relationshipType

	new() { }
	new((NotationEdge) => void initializer) {
		initializer.apply(this)
	}
}

@Accessors
class AssociativeRelationshipEdge extends SEdge {
	String notation
	String sourceConnectivity
	String targetConnectivity

	new() { }
	new((AssociativeRelationshipEdge) => void initializer) {
		initializer.apply(this)
	}
}

@Accessors
class PopupButton extends PreRenderedElement {
	String target
	String kind

	new() { }
	new((PopupButton) => void initializer) {
		initializer.apply(this)
	}
}
