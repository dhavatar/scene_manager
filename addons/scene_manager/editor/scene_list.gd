@tool
extends Node

# Scene itema and sub_section to instance and add in list
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")
const SUB_SECTION = preload("res://addons/scene_manager/editor/sub_section.tscn")
# Duplicate/invalid + normal scene theme
const DUPLICATE_LINE_EDIT: StyleBox = preload("res://addons/scene_manager/themes/line_edit_duplicate.tres")

# variables
@onready var _container: VBoxContainer = find_child("container")
@onready var _delete_list_button: Button = find_child("delete_list")

var _root: Node = self
var _main_subsection: Node = null
var _secondary_subsection: Node = null


# Finds and fills `_root` variable properly
#
# Start up of `All` list
func _ready() -> void:
	while true:
		if _root == null:
			## If we are here, we are running in editor, so get out
			break
		elif _root.name == "Scene Manager" || _root.name == "menu":
			break
		_root = _root.get_parent()

	if self.name == "All":
		_delete_list_button.icon = null
		_delete_list_button.disabled = true
		_delete_list_button.visible = false
		_delete_list_button.focus_mode = Control.FOCUS_NONE

	var sub = SUB_SECTION.instantiate()
	sub._root = _root
	sub.name = "All"
	sub.visible = false
	_container.add_child(sub)
	sub.open()
	sub.hide_delete_button()
	_main_subsection = sub

	# Have to deferr the call as the object won't be ready yet at this point
	sub.call_deferred("set_closable", false if name == "All" else true)


## Adds an item to list
func add_item(key: String, value: String) -> void:
	if not self.is_node_ready():
		await self.ready
	
	var item = SCENE_ITEM.instantiate()
	item.set_key(key)
	item.set_value(value)
	item._list = self
	_main_subsection.add_item(item)


## Updates the item key with the new key.
func update_item_key(key: String, new_key: String) -> void:
	# Find the item in the different subsections and update them
	for section in _container.get_children():
		# We want to get the list, which will be the second child in the sub section
		var list := section.get_child(1)
		var nodes := list.get_children()

		# Find the node we're looking for to replace
		# The node is a scene_item.
		for node in nodes:
			if node.get_key() == key:
				node.set_key(new_key)
				_sort_node_list(list)
				break


## Finds and returns a sub_section in the list
func find_subsection(key: String) -> Node:
	for element in _container.get_children():
		if element.name == key:
			return element
	return null


## Removes an item from list
func remove_item(key: String, value: String) -> void:
	for i in range(_container.get_child_count()):
		var children: Array = _container.get_child(i).get_items()
		for j in range(len(children)):
			if children[j].get_key() == key && children[j].get_value() == value:
				children[j].queue_free()
				return


## Removes items that their value begins with passed value
func remove_items_begins_with(value: String) -> void:
	for i in range(_container.get_child_count()):
		var children: Array = _container.get_child(i).get_items()
		for j in range(len(children)):
			if children[j].get_value().begins_with(value):
				children[j].queue_free()


## Clear all scene records from UI list
func clear_list() -> void:
	for i in range(_container.get_child_count()):
		_container.get_child(i).queue_free()


## Appends all scenes into UI list[br]
##
## This function is used for new items that are new in project directory and are
## not saved before, so they have no settings.[br]
##
## Input example:
## {"scene_key": "scene_address", "scene_key": "scene_address", ...}
func append_scenes(nodes: Dictionary) -> void:
	for key in nodes:
		add_item(key, nodes[key])


## Sort the scenes in all the subsections alphabetically based on the scene key name.
func sort_scenes() -> void:
	for section in _container.get_children():
		# We want to get the list, which will be the second child in the sub section
		var list := section.get_child(1)
		_sort_node_list(list)


# Internal helper method to sort a list of nodes under a given parent.
func _sort_node_list(parent: Node) -> void:
		var sorted_nodes := parent.get_children()
		sorted_nodes.sort_custom(
			func(a: Node, b: Node): return a.get_key().naturalnocasecmp_to(b.get_key()) < 0
		)

		for i in range(sorted_nodes.size()):
			if sorted_nodes[i].get_index() != i:
				parent.move_child(sorted_nodes[i], i)


## Return an array of record nodes from UI list
func get_list_nodes() -> Array:
	if _container == null:
		_container = find_child("container")
	var arr: Array[Node] = []
	for i in range(_container.get_child_count()):
		var nodes = _container.get_child(i).get_items()
		arr.append_array(nodes)
	return arr


## Returns a specific node from passed scene name
func get_node_by_scene_name(scene_name: String) -> Node:
	for i in range(_container.get_child_count()):
		var items = _container.get_child(i).get_items()
		for j in range(len(items)):
			if items[j].get_key() == scene_name:
				return items[j]
	return null


## Returns a specific node from passed scene address
func get_node_by_scene_address(scene_address: String) -> Node:
	for i in range(_container.get_child_count()):
		var items = _container.get_child(i).get_items()
		for j in range(len(items)):
			if items[j].get_value() == scene_address:
				return items[j]
	return null


## Update a specific scene record with passed data in UI
func update_scene_with_key(key: String, new_key: String, value: String) -> void:
	for i in range(_container.get_child_count()):
		var children: Array[Node] = _container.get_child(i).get_items()
		for j in range(len(children)):
			if children[j].get_key() == key && children[j].get_value() == value:
				children[j].set_key(new_key)


## Checks duplication in current list and return their scene addresses in an array from UI
func check_duplication() -> Array:
	var all: Array[Node] = get_list_nodes()
	var arr: Array[String] = []
	for i in range(len(all)):
		var j: int = i + 1
		while j < len(all):
			var child1: Node = all[i]
			var child2: Node = all[j]
			if child1.get_key() == child2.get_key():
				if !(child1.get_key() in arr):
					arr.append(child1.get_key())
			j += 1
	return arr


## Reset theme for all children in UI
func set_reset_theme_for_all() -> void:
	for i in range(_container.get_child_count()):
		var children: Array[Node] = _container.get_child(i).get_items()
		for j in range(len(children)):
			children[j].remove_custom_theme()


## Sets duplicate theme for children in passed list in UI
func set_duplicate_theme(list: Array) -> void:
	for i in range(_container.get_child_count()):
		var children: Array[Node] = _container.get_child(i).get_items()
		for j in range(len(children)):
			if children[j].get_key() in list:
				children[j].custom_set_theme(DUPLICATE_LINE_EDIT)


## Returns all names of sublist
func get_all_sublists() -> Array:
	var arr: Array[String] = []
	for i in range(_container.get_child_count()):
		arr.append(_container.get_child(i).name)
	return arr


## Adds a subsection
func add_subsection(text: String) -> Control:
	var sub = SUB_SECTION.instantiate()
	sub._root = _root
	sub.name = text.capitalize()
	_container.add_child(sub)
	return sub


# List deletion
func _on_delete_list_button_up() -> void:
	var section_name = self.name
	if self.name == "All":
		return
	queue_free()
	await self.tree_exited
	_root.section_removed.emit(self, section_name)
