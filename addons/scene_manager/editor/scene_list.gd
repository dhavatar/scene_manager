@tool
extends Node

# Scene item and sub_section to instance and add in list
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")
const SUB_SECTION = preload("res://addons/scene_manager/editor/sub_section.tscn")
# Duplicate/invalid + normal scene theme
const DUPLICATE_LINE_EDIT: StyleBox = preload("res://addons/scene_manager/themes/line_edit_duplicate.tres")
const ALL_LIST_NAME := "All"

@onready var _container: VBoxContainer = find_child("container")
@onready var _delete_list_button: Button = find_child("delete_list")

var _root: Node = self
var _main_subsection: Node = null # "All" subsection by default. In the "All" list, this is "Uncategorized" items
var _secondary_subsection: Node = null # Mainly used for the default "All" list for "Categorized" items


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

	if name == ALL_LIST_NAME:
		_delete_list_button.icon = null
		_delete_list_button.disabled = true
		_delete_list_button.visible = false
		_delete_list_button.focus_mode = Control.FOCUS_NONE

		var sub = SUB_SECTION.instantiate()
		sub._root = _root
		sub.name = "Uncategorized"
		_container.add_child(sub)
		sub.open()
		sub.enable_delete_button(false)
		sub.set_delete_visible(false)
		_main_subsection = sub

		var sub2 = SUB_SECTION.instantiate()
		sub._root = _root
		sub2.name = "Categorized"
		_container.add_child(sub2)
		sub2.enable_delete_button(false)
		sub2.set_delete_visible(false)
		_secondary_subsection = sub2
	else:
		var sub = SUB_SECTION.instantiate()
		sub._root = _root
		sub.name = ALL_LIST_NAME
		sub.visible = false
		_container.add_child(sub)
		sub.open()
		sub.set_header_visible(false)
		sub.enable_delete_button(false)
		sub.set_delete_visible(false)
		_main_subsection = sub


## Adds an item to list
func add_item(key: String, value: String, categorized: bool = false) -> void:
	if not self.is_node_ready():
		await self.ready
	
	var item = SCENE_ITEM.instantiate()
	item.set_key(key)
	item.set_value(value)
	item._list = self

	# For the default All case, determine which sub category it goes into
	if name == ALL_LIST_NAME and categorized:
		_secondary_subsection.add_item(item)
	else:
		_main_subsection.add_item(item)


## Updates whether or not the item is categorized and moves it to the correct subcategory.[br]
## Used for the default "All" list.
func update_item_categorized(key: String, categorized: bool) -> void:
	# Make sure this is the correct list
	if name != ALL_LIST_NAME:
		push_warning("Cannot set categorization in a list other than All (attempting to set in %s)" % name)
		return
	
	# Find the item in the sub sections.
	var item = _main_subsection.get_item(key)
	if item:
		# If the item is already not categorized, then nothing needs to be done
		if not categorized:
			return
		
		# Otherwise, the item should go into the "Categorized"
		_main_subsection.remove_item(item)
		_secondary_subsection.add_item(item)
		_sort_node_list(_secondary_subsection.get_list_container())
		return
	
	item = _secondary_subsection.get_item(key)
	if item:
		# If it's already categorized, nothing needs to be done
		if categorized:
			return
		
		# Otherwise, the item should go into the "Uncategorized"
		_secondary_subsection.remove_item(item)
		_main_subsection.add_item(item)
		_sort_node_list(_main_subsection.get_list_container())
		return


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
		var list = section.get_list_container()
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
