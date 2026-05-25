class_name Fn

static func setup_node_refs(node: Node, properties: PackedStringArray, do_assert := true) -> PackedStringArray:
	var res = []
	var props = []
	for prop in properties:
		if not prop in node: continue
		if node.get(prop): continue
		var ref = node.get_node_or_null(prop.to_pascal_case())
		if not ref:
			res.append(prop.to_pascal_case())
			props.append(prop)
		else:
			node.set(prop, ref)
	if do_assert and res.size():
		assert(false, "On node %s: Following node references properties don't have a value set in editor: %s. By default we expect these to exist as children with the following names: %s" % [node.name, ", ".join(props), ", ".join(res)])
	return res

func _init():
	assert(false)
