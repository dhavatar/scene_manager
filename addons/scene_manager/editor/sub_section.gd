@tool
extends Control

# Nodes
@onready var _button: Button = find_child("Button")
@onready var _delete_button: Button = find_child("Delete")
@onready var _list: VBoxContainer = find_child("List")

const SUBSECTION_OPEN_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowDown.svg")
const SUBSECTION_CLOSE_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowRight.png")
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")

var _root: Node = self
var _is_closable: bool = true


# If it is "All" subsection, open it
func _ready() -> void:
	_button.text = name
	if name == "All" && get_child_count() == 0:
		visible = false


# Add child
func add_item(item: Node) -> void:
	item._sub_section = self
	_list.add_child(item)


# Removes an item from list
func remove_item(item: Node) -> void:
	_list.remove_child(item)


# Open list
func open() -> void:
	_list.visible = true
	_button.icon = SUBSECTION_OPEN_ICON


# Close list
func close() -> void:
	_list.visible = false
	_button.icon = SUBSECTION_CLOSE_ICON


# Returns list of items
func get_items() -> Array:
	return _list.get_children()


# Close Open Functionality
func _on_button_up():
	if _is_closable:
		if _button.icon == SUBSECTION_OPEN_ICON:
			close()
		else:
			open()


# Action on child counting
func _check_count():
	if _list.get_child_count() == 0:
		if name == "All":
			visible = false
		else:
			enable_delete_button()
	else:
		if name == "All":
			visible = true
		else:
			disable_delete_button()


# When a node adds
func child_entered():
	_check_count()


# When a node removes
func child_exited():
	_check_count()


# Hides delete button of subsection
func hide_delete_button():
	_delete_button.visible = false


# Disables delete button
func disable_delete_button():
	_delete_button.disabled = true


# Enables delete button
func enable_delete_button():
	_delete_button.disabled = false


## Sets whether or not the subsection can close.
func set_closable(can_close: bool) -> void:
	_is_closable = can_close

	if _is_closable:
		_button.icon = SUBSECTION_OPEN_ICON if _list.visible else SUBSECTION_CLOSE_ICON
	else:
		_button.icon = null


# Returns if we can drop here or not
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !(data is Dictionary):
		return false
	data = data as Dictionary
	return data.has("node") and data.has("parent")


# Function to actually do the dropping
func _drop_data(at_position: Vector2, data: Variant) -> void:
	data = data as Dictionary
	var parent = data["parent"] as Node
	var node = data["node"] as Node
	var setting = node.get_setting() as ItemSetting
	if parent == self:
		return
	parent.remove_item(node)
	node.set_subsection(self)
	add_item(node)
	open()
	if name == "All":
		node.set_setting(ItemSetting.default())
		_root.added_to_sub_section.emit(node, self)
		return
	_root.added_to_sub_section.emit(node, self)
	setting.subsection = name
	node.set_setting(setting)
	_root.sub_section_removed.emit(self)


# Button Delete 
func _on_delete_button_up():
	queue_free()
	await self.tree_exited
	_root.sub_section_removed.emit(self)
