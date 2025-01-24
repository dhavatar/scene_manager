extends Node
## Main SceneManager that handles adding scenes and transitions.

const FADE: String = "fade"
const DEFAULT_TREE_NODE_NAME: String = "World" ## Default node name to be used for loading scenes
const _MAP_PARENT_INDEX: int = 0 # Index to the loaded scene map for the parent node
const _MAP_SCENE_INDEX: int = 1 # Index to the loaded scene map for the scene node

## Enums for how to load the scene.[br]
## Single will make it so only one scene will exist for the whole tree. Default option.[br]
## Single_Node will make it so only one scene will exist for the specified node.[br]
## Additive will add the scene to the node along with anything else loaded.
enum SceneLoadingMode { SINGLE, SINGLE_NODE, ADDITIVE }

# Built in fade in/out for scene loading
@onready var _fade_color_rect: ColorRect = find_child("fade")
@onready var _animation_player: AnimationPlayer = find_child("animation_player")
@onready var _in_transition: bool = false
@onready var _back_buffer: RingBuffer = RingBuffer.new()
@onready var _current_scene: Scenes.SceneName = Scenes.SceneName.NONE

var _load_scene: String = "" ## Scene path that is currently loading
var _load_scene_enum: Scenes.SceneName = Scenes.SceneName.NONE ## Scene Enum of the scene that's currently loading
var _load_progress: Array = []
var _recorded_scene: Scenes.SceneName = Scenes.SceneName.NONE
var _loaded_scene_map: Dictionary = {} ## Keeps track of all loaded scenes (SceneName key) and the node they belong to in an array (parent node: Node, scene node: Node)
var _data: SceneManagerData = SceneManagerData.new()

signal load_finished
signal load_percent_changed(value: int)
signal scene_loaded
signal fade_in_started
signal fade_out_started
signal fade_in_finished
signal fade_out_finished


## Parameter options to send when loading a new scene
class SceneLoadOptions:
	var node_name: String = DEFAULT_TREE_NODE_NAME ## Where in the node structure the new scene will load.
	var mode: SceneLoadingMode = SceneLoadingMode.SINGLE ## Whether to only have a single scene or an additive load. Defaults to SINGLE.
	var fade_out_time: float = ProjectSettings.get_setting(SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME, SceneManagerConstants.DEFAULT_FADE_OUT_TIME)
	var fade_in_time: float = ProjectSettings.get_setting(SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME, SceneManagerConstants.DEFAULT_FADE_IN_TIME)
	var clickable: bool = true ## Whether or not to block mouse input during the scene load. Defaults to true.
	var add_to_back: bool = true ## Whether or not to add the scene onto the stack so the scene can go back to it.


func _ready() -> void:
	set_process(false)
	
	_data.load()
	var scene_file_path: String = get_tree().current_scene.scene_file_path
	_current_scene = _get_scene_key_by_value(scene_file_path)

	call_deferred("_on_initial_setup")


# Used for interactive change scene
func _process(_delta: float) -> void:
	var prevPercent: int = 0
	if len(_load_progress) != 0:
		prevPercent = int(_load_progress[0] * 100)
	
	var status = ResourceLoader.load_threaded_get_status(_load_scene, _load_progress)
	var nextPercent: int = int(_load_progress[0] * 100)
	if prevPercent != nextPercent:
		load_percent_changed.emit(nextPercent)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_load_progress = []
		load_finished.emit()
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		pass
	else:
		assert(false, "Scene Manager Error: for some reason, loading failed.")


func _current_scene_is_included(scene_file_path: String) -> bool:
	for include_path in Scenes.scenes._include_list:
		if scene_file_path.begins_with(include_path):
			return true
	return false


# For the initial setup, move the current scene to the default parent node and store it in the mapping.
func _on_initial_setup() -> void:
	var scene_node := get_tree().current_scene
	var root := get_tree().root

	var default_node := Node.new()
	default_node.name = DEFAULT_TREE_NODE_NAME

	root.remove_child(scene_node)
	default_node.add_child(scene_node)
	root.add_child(default_node)

	# Don't map a NONE scene as that shouldn't be here. It's possible to reach here
	# if the loaded scene wasn't part of the enums and loaded some other way.
	if _current_scene != Scenes.SceneName.NONE:
		_loaded_scene_map[_current_scene] = [default_node, scene_node]
	else:
		push_warning("Loaded scene not added to the mapping due to being NONE.")


# `speed` unit is in seconds
func _fade_in(speed: float) -> bool:
	if speed == 0:
		return false
	
	fade_in_started.emit()
	_animation_player.play(FADE, -1, -1 / speed, true)
	return true


# `speed` unit is in seconds
func _fade_out(speed: float) -> bool:
	if speed == 0:
		return false

	fade_out_started.emit()
	_animation_player.play(FADE, -1, 1 / speed, false)
	return true


# Activates `in_transition` mode
func _set_in_transition() -> void:
	_in_transition = true


# Deactivates `in_transition` mode
func _set_out_transition() -> void:
	_in_transition = false


# Adds current scene to `_back_buffer`
func _append_stack(key: Scenes.SceneName) -> void:
	_back_buffer.push(key)


# Pops most recent added scene from `_back_buffer`
func _pop_stack() -> Scenes.SceneName:
	var pop := _back_buffer.pop()
	if pop:
		return pop
	return Scenes.SceneName.NONE


# Changes scene to the previous scene.[br]
# Note this assumes Single loading and will remove any additive scenes with default options.
func _back() -> bool:
	var pop: Scenes.SceneName = _pop_stack()
	if pop != Scenes.SceneName.NONE and _current_scene != Scenes.SceneName.NONE:
		# Use the same parent node the scene currently has to keep it consistent.
		var load_options := SceneLoadOptions.new()
		load_options.node_name = _loaded_scene_map[_current_scene][_MAP_PARENT_INDEX].name
		load_options.add_to_back = false
		load_scene(pop, load_options)
		return true
	return false


# Returns the scene key of the passed scene value (scene address)
func _get_scene_key_by_value(path: String) -> Scenes.SceneName:
	for key in _data.scenes:
		if _data.scenes[key]["value"] == path:
			# Convert the string into an enum
			return SceneManagerUtils.get_enum_from_string(key)
			
	return Scenes.SceneName.NONE


# Returns the raw dictionary values for the scene
func _get_scene_value(scene: Scenes.SceneName) -> String:
	# The enums are normalized to have all caps, but the keys in the scenes may not have that,
	# do a string comparison with everything normalized.
	var scene_name: String = SceneManagerUtils.get_string_from_enum(scene)
	for key in _data.scenes:
		if scene_name == SceneManagerUtils.normalize_enum_string(key):
			return _data.scenes[key]["value"]
	
	return ""


# Restart the currently loaded scene
func _refresh() -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	var load_options := SceneLoadOptions.new()
	load_options.node_name = _loaded_scene_map[_current_scene][_MAP_PARENT_INDEX].name
	load_options.add_to_back = false
	load_scene(_current_scene, load_options)
	return true


# Makes menu clickable or unclickable during transitions
func _set_clickable(clickable: bool) -> void:
	if clickable:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


## Limits how deep the scene manager is allowed to record previous scenes which
## affects in changing scene to `back`(previous scene) functionality.[br]
##
## allowed `input` values:[br]
## input =  0 => we can not go back to any previous scenes[br]
## input >  0 => we can go back to `input` or less previous scenes[br]
func set_back_limit(input: int) -> void:
	input = maxi(input, 0)
	_back_buffer.set_capacity(input)


## Clears the `_back_buffer`.
func clear_back_buffer() -> void:
	_back_buffer.clear()


## Creates options for loading a scene.[br]
##
## add_to_back means that you can go back to the scene if you
## change scene to `back` scene
func create_load_options(
		node: String = DEFAULT_TREE_NODE_NAME,
		mode: SceneLoadingMode = SceneLoadingMode.SINGLE,
		clickable: bool = true,
		fade_out_time: float = ProjectSettings.get_setting(SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME, SceneManagerConstants.DEFAULT_FADE_OUT_TIME),
		fade_in_time: float = ProjectSettings.get_setting(SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME, SceneManagerConstants.DEFAULT_FADE_IN_TIME),
		add_to_back: bool = true) -> SceneLoadOptions:
	var options: SceneLoadOptions = SceneLoadOptions.new()
	options.node_name = node
	options.mode = mode
	options.fade_out_time = fade_out_time
	options.fade_in_time = fade_in_time
	options.clickable = clickable
	options.add_to_back = add_to_back
	return options


## Returns scene instance of passed scene key (blocking).[br]
##
## Note: you can activate `use_sub_threads` but just know that In the newest 
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene 
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
##
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func create_scene_instance(key: Scenes.SceneName, use_sub_threads = false) -> Node:
	return get_scene(key, use_sub_threads).instantiate()


## Returns PackedScene of passed scene key (blocking).[br]
##
## Note: you can activate `use_sub_threads` but just know that In the newest 
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene 
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
##
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func get_scene(key: Scenes.SceneName, use_sub_threads = false) -> PackedScene:
	var address = _data.scenes[key]["value"]
	ResourceLoader.load_threaded_request(address, "", use_sub_threads, ResourceLoader.CACHE_MODE_REUSE)
	return ResourceLoader.load_threaded_get(address)


## Loads a specified scene to the tree.[br]
## By default it will swap the scene with the one already loaded in the default tree node.
func load_scene(scene: Scenes.SceneName,
		load_options: SceneLoadOptions = create_load_options()) -> void:
	if scene == Scenes.SceneName.NONE:
		push_warning("Attempted to load a NONE scene. Skipping load as it won't work.")
		return

	_set_in_transition()
	_set_clickable(load_options.clickable)

	if _fade_out(load_options.fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()

	var root := get_tree().get_root()

	# If doing single scene loading, delete the specified node and load
	# the scene into the default node.
	var parent_node: Node = null
	var new_scene_node: Node = null
	if load_options.mode == SceneLoadingMode.SINGLE or load_options.mode == SceneLoadingMode.SINGLE_NODE:
		# For the Single case, remove all nodes. For the Single Node case, only remove the specified
		# node in the options.
		if load_options.mode == SceneLoadingMode.SINGLE:
			_unload_all_nodes()
		else:
			# If the node currently exists, completely remove it and recreate a blank node after
			if root.has_node(load_options.node_name):
				_unload_node(load_options.node_name)
		
		parent_node = Node.new()
		parent_node.name = load_options.node_name
		root.add_child(parent_node)

		new_scene_node = _load_scene_node_from_path(_get_scene_value(scene))
		parent_node.add_child(new_scene_node)

		# Note we add the current scene to back buffer and not the new scene coming in
		# as we want the old scene to revert to if needed.
		if load_options.add_to_back:
			_append_stack(_current_scene)
	else:
		# For additive, add the node if it doesn't exist then load the scene into that node.
		if not root.has_node(load_options.node_name):
			parent_node = Node.new()
			parent_node.name = load_options.node_name
			root.add_child(parent_node)
		else:
			parent_node = root.get_node(load_options.node_name)
		
		assert(parent_node, "ERROR: Could not get the node %s to use for the additive scene." % load_options.node_name)
		
		print("Loading scene from path")
		new_scene_node = _load_scene_node_from_path(_get_scene_value(scene))
		print("Adding child to scene")
		parent_node.add_child(new_scene_node)

	# Keep track of the loaded scene enum to the node it's a child of.
	_loaded_scene_map[scene] = [parent_node, new_scene_node]
	_current_scene = scene
	scene_loaded.emit()

	if _fade_in(load_options.fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_clickable(true)
	_set_out_transition()


## Unloads the scene from the tree.
func unload_scene(scene: Scenes.SceneName) -> void:
	# Get the node from the map, free it, and cleans up the map
	if not _loaded_scene_map.has(scene):
		assert("ERROR: Attempting to remove a scene %s that has not been loaded." % SceneManagerUtils.get_string_from_enum(scene))
	
	_loaded_scene_map[scene][_MAP_SCENE_INDEX].free()
	_loaded_scene_map.erase(scene)


## Frees the node and all children node underneath while removing the scenes in the map assocaited with them.[br]
## Mainly used when removing the parent node, which will cause all the scenes to be removed.
func _unload_node(node_name: String) -> void:
	if not get_tree().root.has_node(node_name):
		assert("ERROR: Attempting to remove the parent node %s that doesn't exist." % node_name)
	
	# Using the node name, find all the scenes that are loaded under it and free them before
	# removing the parent node itself.
	for key in _loaded_scene_map.keys():
		if _loaded_scene_map[key][_MAP_PARENT_INDEX].name == node_name:
			_loaded_scene_map[key][_MAP_SCENE_INDEX].free()
			_loaded_scene_map.erase(key)
	
	get_tree().root.get_node(node_name).free()


## Frees all scene related nodes in the loaded scene map.[br]
## Used mainly for Single scene loading which will unload all scenes. 
func _unload_all_nodes() -> void:
	# Get a list of all unique parent nodes to remove
	# Using the dictionary keys as a set.
	var unique_nodes := {}
	for key in _loaded_scene_map:
		if not unique_nodes.has(_loaded_scene_map[key][_MAP_PARENT_INDEX]):
			unique_nodes[_loaded_scene_map[key][_MAP_PARENT_INDEX]] = null

	# Go through each parent node and unload them
	for node in unique_nodes:
		_unload_node(node.name)


## Loads a scene from the specified file path and returns the Node for it.[br]
## Returns null if the scene doesn't exist.
func _load_scene_node_from_path(path: String) -> Node:
	var result: Node = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = ResourceLoader.load(path)
		if scene:
			result = scene.instantiate()
		if not result:
			printerr("ERROR: %s scene path can't load" % path)

	return result


## Changes the scene to the previous.
func go_back() -> void:
	_back()


## Reload the currently loaded scene.
func reload_current_scene() -> void:
	_refresh()


# Exits the game completely.
func exit_game() -> void:
	get_tree().quit(0)


## Imports loaded scene into the scene tree but doesn't change the scene
## mainly used when your new loaded scene has a loading phase when added to scene tree
## so to use this, first has to call `load_scene_interactive` to load your scene
## and then have to listen on `load_finished` signal and after the signal emits,
## you call this function and this function adds the loaded scene to the scene
## tree but exactly behind the current scene so that you still can not see the new scene
func add_loaded_scene_to_scene_tree() -> void:
	if _load_scene != "":
		var scene_resource = ResourceLoader.load_threaded_get(_load_scene) as PackedScene
		if scene_resource:
			var scene = scene_resource.instantiate()
			scene.scene_file_path = _load_scene
			var root = get_tree().get_root()
			root.add_child(scene)
			root.move_child(scene, root.get_child_count() - 2)
			_load_scene = ""
			_load_scene_enum = Scenes.SceneName.NONE


## When you added the loaded scene to the scene tree by `add_loaded_scene_to_scene_tree`
## function, you call this function after you are sure that the added scene to scene tree
## is completely ready and functional to change the active scene
func change_scene_to_existing_scene_in_scene_tree(load_options: SceneLoadOptions = create_load_options()) -> void:
	_set_in_transition()
	_set_clickable(load_options.clickable)
	
	if _fade_out(load_options.fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()

	# actual change scene goes here
	var root = get_tree().get_root()
	# delete the loading screen scene
	root.get_child(root.get_child_count() - 1).free()
	# get the loaded, completely generated scene
	var scene = root.get_child(root.get_child_count() - 1)
	# inform godot which now this is the current scene
	get_tree().set_current_scene(scene)

	# keeping the track of current scene and previous scenes
	var path: String = scene.scene_file_path
	var found_key: Scenes.SceneName = _get_scene_key_by_value(path)
	if load_options.add_to_back && found_key != Scenes.SceneName.NONE:
		_append_stack(found_key)
	
	if _fade_in(load_options.fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_clickable(true)
	_set_out_transition()


## Loads scene interactive[br]
##
## Connect to `load_percent_changed(value: int)` and `load_finished` signals
## to listen to updates on your scene loading status.[br]
##
## Note: You can activate `use_sub_threads` but just know that in the newest 
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene 
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
## 
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func load_scene_interactive(key: Scenes.SceneName, use_sub_threads = false) -> void:
	set_process(true)
	_load_scene = _get_scene_value(key)
	_load_scene_enum = key
	ResourceLoader.load_threaded_request(_load_scene, "", use_sub_threads, ResourceLoader.CACHE_MODE_IGNORE)


## Returns the loaded scene.[br]
##
## If scene is not loaded, blocks and waits until scene is ready (acts blocking in code
## and may freeze your game, make sure scene is ready to get).
func get_loaded_scene() -> PackedScene:
	if _load_scene != "":
		return ResourceLoader.load_threaded_get(_load_scene) as PackedScene
	return null


## Changes scene to loaded scene
func change_scene_to_loaded_scene(load_options: SceneLoadOptions) -> void:
	if _load_scene != "":
		var scene = ResourceLoader.load_threaded_get(_load_scene) as PackedScene
		if scene:
			load_scene(_load_scene_enum, load_options)


## Pops from the back stack and returns previous scene (scene before current scene)
func pop_previous_scene() -> Scenes.SceneName:
	return _pop_stack()


## Returns how many scenes there are in list of previous scenes.
func previous_scenes_length() -> int:
	return _back_buffer.size()


## Records a scene key to be used for loading scenes to know where to go after getting loaded
## into loading scene or just for next scene to know where to go next.
func set_recorded_scene(key: Scenes.SceneName) -> void:
	_recorded_scene = key


## Returns recorded scene
func get_recorded_scene() -> Scenes.SceneName:
	return _recorded_scene


## Pause (fadeout). You can resume afterwards.
func pause(fade_out_time: float, general_options: SceneLoadOptions = create_load_options()) -> void:
	_set_in_transition()
	_set_clickable(general_options.clickable)
	
	if _fade_out(fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()


## Resume (fadein) after pause
func resume(fade_in_time: float, general_options: SceneLoadOptions = create_load_options()) -> void:
	_set_clickable(general_options.clickable)
	
	if _fade_in(fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_out_transition()
	_set_clickable(true)
