@tool
extends MarginContainer
## Editor manager for generating necessary files and getting scene information.
##
## Handles UI callbacks for modifying data and writes the scene.gd file which
## stores all the scene information in the project.

# Scene item, include item prefabs
const SCENE_INCLUDE_ITEM = preload("res://addons/scene_manager/editor/deletable_item.tscn")
const SCENE_LIST_ITEM = preload("res://addons/scene_manager/editor/scene_list.tscn")

# Icons
const ICON_HIDE_BUTTON_CHECKED = preload("res://addons/scene_manager/icons/GuiChecked.svg")
const ICON_HIDE_BUTTON_UNCHECKED = preload("res://addons/scene_manager/icons/GuiCheckedDisabled.svg")
const ICON_FOLDER_BUTTON_CHECKED = preload("res://addons/scene_manager/icons/FolderActive.svg")
const ICON_FOLDER_BUTTON_UNCHECKED = preload("res://addons/scene_manager/icons/Folder.svg")

# UI nodes and items
@onready var _include_list: Node = self.find_child("include_list")
# add save, refresh
@onready var _save_button: Button = self.find_child("save")
@onready var _refresh_button: Button = self.find_child("refresh")
@onready var _auto_save_button: Button = self.find_child("auto_save")
# add list
@onready var _add_section_button: Button = self.find_child("add_section")
@onready var _section_name_line_edit: LineEdit = self.find_child("section_name")
# add include
@onready var _address_line_edit: LineEdit = self.find_child("address")
@onready var _file_dialog: FileDialog = self.find_child("file_dialog")
@onready var _add_button: Button = self.find_child("add")
# containers
@onready var _tab_container: TabContainer = self.find_child("tab_container")
@onready var _include_container: Node = self.find_child("includes")
@onready var _include_panel_container: Node = self.find_child("include_panel")

var _data: SceneManagerData = SceneManagerData.new()
var _autosave_timer: Timer = null ## Timer for autosave when the key changes

# UI signal callbacks
signal include_child_deleted(node: Node, address: String)
signal item_renamed(node: Node, previous_name: String, new_name: String)
signal item_visibility_changed(node: Node, visibility: bool)
signal item_added_to_list(node: Node, list_name: String)
signal item_removed_from_list(node: Node, list_name: String)
signal section_removed(node: Node, section_name: String)


func _ready() -> void:
	_data.load()
	
	# Refreshes the UI with the latest data
	_on_refresh_button_up()
	_change_auto_save_state(_data.auto_save)

	self.include_child_deleted.connect(_on_include_child_deleted)
	self.item_renamed.connect(_on_item_renamed)
	self.item_visibility_changed.connect(_on_item_visibility_changed)
	self.item_added_to_list.connect(_on_added_to_list)
	self.item_removed_from_list.connect(_on_item_removed_from_list)
	self.section_removed.connect(_on_section_removed)

	# Create a new Timer node to write to the scenes.gd file when the timer ends
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 0.5
	_autosave_timer.one_shot = true
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(_on_timer_timeout)


#region Signal Callbacks

func _on_data_changed() -> void:
	if _data.auto_save:
		_data.save()


func _on_section_removed(node: Node, section_name: String) -> void:
	_data.remove_section(section_name)
	_on_data_changed()


func _on_timer_timeout() -> void:
	_on_data_changed()


func _on_item_renamed(node: Node, previous_name: String, new_name: String) -> void:
	_data.change_name(previous_name, new_name)
	_rename_scene_in_lists(previous_name, new_name)
	
	if _data.auto_save:
		_autosave_timer.wait_time = 0.5
		_autosave_timer.start()


func _on_item_visibility_changed(node: Node, visibility: bool) -> void:	
	_on_data_changed()


func _on_added_to_list(node: Node, list_name: String) -> void:
	_data.add_scene_to_section(node.get_value(), list_name)
	_on_data_changed()


func _on_item_removed_from_list(node: Node, list_name: String) -> void:
	_data.remove_scene_from_section(node.get_value(), list_name)
	_on_data_changed()


# When an include item remove button clicks
func _on_include_child_deleted(node: Node, address: String) -> void:
	node.queue_free()
	await node.tree_exited
	_data.remove_include_path(address)
	_on_data_changed()
	_on_refresh_button_up()

#endregion Signal Callbacks


## Retrieves the available sections from the data.
func get_sections(address: String) -> Array:
	return _data.get_scene_sections(address)


# Returns absolute current working directory
func _absolute_current_working_directory() -> String:
	return ProjectSettings.globalize_path(EditorPlugin.new().get_current_directory())


# Returns names of all lists from UI
func get_all_lists_names_except(excepts: Array = [""]) -> Array:
	var arr: Array = []
	for i in range(len(excepts)):
		excepts[i] = excepts[i].capitalize()
	for node in _get_lists_nodes():
		if node.name in excepts:
			continue
		arr.append(node.name)
	return arr


# Clears scenes inside a UI list
func _clear_scenes_list(name: String) -> void:
	var list: Node = _get_scene_list_node_by_name(name)
	if list != null:
		list.clear_list()


# Clears scenes inside all UI lists
func _clear_all_lists() -> void:
	for list in _get_lists_nodes():
		list.clear_list()


# Removes all tabs in scene manager
func _delete_all_tabs() -> void:
	for node in _get_lists_nodes():
		node.free()


# Returns nodes of all section lists from UI in `Scene Manager` tool
func _get_lists_nodes() -> Array:
	return _tab_container.get_children()


# Returns node of a specific list in UI.
# Note that the Node is part of `scene_list.gd` and has access to those functions.
func _get_scene_list_node_by_name(name: String) -> Node:
	for node in _get_lists_nodes():
		if name.capitalize() == node.name:
			return node
	return null


# Sorts all the lists in the UI based on the key name.
func _sort_scenes_in_lists() -> void:
	for list_node in _get_lists_nodes():
		list_node.sort_scenes()


# Renames a scene in all the lists.
func _rename_scene_in_lists(key: String, new_key: String) -> void:
	for list_node in _get_lists_nodes():
		list_node.update_item_key(key, new_key)
		list_node.sort_scenes()


# Removes a scene from a specific list
func remove_scene_from_list(section_name: String, scene_name: String, scene_address: String) -> void:
	var list: Node = _get_scene_list_node_by_name(section_name)
	list.remove_item(scene_name, scene_address)


## Adds an item to a list
##
## This function is used in `scene_item.gd` script and plus doing what it is supposed
## to do, removes and again adds the item in `All` section so that it can be placed
## in correct place in correct section.
func add_scene_to_list(list_name: String, scene_name: String, scene_address: String) -> void:
	var list: Node = _get_scene_list_node_by_name(list_name)
	if list == null:
		return
	await list.add_item(scene_name, scene_address)


# Adds an address to the include list
func _add_include_ui_item(address: String) -> void:
	var item := SCENE_INCLUDE_ITEM.instantiate()
	item.set_address(address)
	_include_list.add_child(item)


# Removes the UI element with the address from the include list
func _remove_include_item(address: String) -> void:
	var remove_item: Node = null
	for node in _include_list.get_children():
		if node.get_address() == address:
			remove_item = node
			break
	
	if remove_item:
		_include_list.remove_child(remove_item)
		remove_item.free()


# Clears all tabs, UI lists and include list
func _clear_all() -> void:
	_delete_all_tabs()
	_clear_all_lists()
	_clear_include_ui_list()


# Reloads all scenes in UI and in this script
func _reload_ui_scenes() -> void:
	for key in _data.scenes:
		var scene = _data.scenes[key]
		for section in scene["sections"]:
			add_scene_to_list(section, key, scene["value"])
		
		add_scene_to_list("All", key, scene["value"])

	_sort_scenes_in_lists()


# Reloads include list in UI
func _reload_ui_includes() -> void:
	_clear_include_ui_list()
	for text in _data.includes:
		_add_include_ui_item(text)


# Reloads tabs in UI
func _reload_ui_tabs() -> void:
	if _get_scene_list_node_by_name("All") == null:
		_add_scene_ui_list("All")
	for section in _data.sections:
		var found = false
		for list in _get_lists_nodes():
			if list.name == section:
				found = true
		if !found:
			_add_scene_ui_list(section)


# Refresh button
func _on_refresh_button_up() -> void:
	_clear_all()
	_reload_ui_tabs()
	_reload_ui_scenes()
	_reload_ui_includes()


## Gets called by other nodes in UI
##
## Updates name of all scene_key.
func update_all_scene_with_key(scene_key: String, scene_new_key: String, value: String, except_list: Array = []):
	for list in _get_lists_nodes():
		if list not in except_list:
			list.update_scene_with_key(scene_key, scene_new_key, value)


## Checks for duplications in scenes of lists
func check_duplication():
	var list: Array = _get_scene_list_node_by_name("All").check_duplication()
	for node in _get_lists_nodes():
		node.set_reset_theme_for_all()
		if list:
			node.set_duplicate_theme(list)


# Save button
func _on_save_button_up():
	_data.save()


# Returns array of include nodes from UI view
func _get_nodes_in_include_ui() -> Array:
	return _include_list.get_children()


# Returns array of addresses to include
func _get_includes_in_include_ui() -> Array:
	var arr: Array = []
	for node in _include_list.get_children():
		arr.append(node.get_address())
	return arr


# Clears includes from UI
func _clear_include_ui_list() -> void:
	for node in _include_list.get_children():
		node.free()


# Returns true if passed address exists in include list
func _include_exists_in_list(address: String) -> bool:
	for node in _get_nodes_in_include_ui():
		if node.get_address() == address or address.begins_with(node.get_address()):
			return true
	return false


# Include list Add button up
func _on_add_button_up():
	if _include_exists_in_list(_address_line_edit.text):
		_address_line_edit.text = ""
		return
	
	_add_include_ui_item(_address_line_edit.text)
	_data.add_include_path(_address_line_edit.text)

	_address_line_edit.text = ""
	_add_button.disabled = true

	_on_data_changed()
	_on_refresh_button_up()


# Pops up file dialog to select a folder to include
func _on_file_dialog_button_button_up():
	_file_dialog.popup_centered(Vector2(600, 600))


# When a file or a dir selects by file dialog
func _on_file_dialog_dir_file_selected(path):
	_address_line_edit.text = path
	_on_address_text_changed(path)


# When include address bar text changes
func _on_address_text_changed(new_text: String) -> void:
	if new_text != "":
		if DirAccess.dir_exists_absolute(new_text) or FileAccess.file_exists(new_text) and new_text.begins_with("res://"):
			_add_button.disabled = false
		else:
			_add_button.disabled = true
	else:
		_add_button.disabled = true


# Adds a new list to the tab container
func _add_scene_ui_list(text: String) -> void:
	var list = SCENE_LIST_ITEM.instantiate()
	list.name = text.capitalize()
	_tab_container.add_child(list)


# Adds the new section to the tab container and to the manager data
func _on_add_section_button_up():
	if _section_name_line_edit.text != "":
		_add_scene_ui_list(_section_name_line_edit.text)
		_data.add_section(_section_name_line_edit.text)

		_section_name_line_edit.text = ""
		_add_section_button.disabled = true

		_on_data_changed()


# When section name text changes
func _on_section_name_text_changed(new_text):
	if new_text != "" && !(new_text.capitalize() in get_all_lists_names_except()):
		_add_section_button.disabled = false
	else:
		_add_section_button.disabled = true


# Tab changes
func _on_tab_container_tab_changed(tab: int):
	_on_section_name_text_changed(_section_name_line_edit.text)


func _change_auto_save_state(value: bool) -> void:
	if !value:
		_save_button.disabled = false
		_auto_save_button.set_meta("enabled", false)
		_auto_save_button.icon = ICON_HIDE_BUTTON_UNCHECKED
	else:
		_auto_save_button.set_meta("enabled", true)
		_auto_save_button.icon = ICON_HIDE_BUTTON_CHECKED
	_save_button.disabled = _auto_save_button.get_meta("enabled", true)


func _on_auto_save_button_up():
	_data.auto_save = not _data.auto_save
	_change_auto_save_state(_data.auto_save)
	_on_data_changed()
