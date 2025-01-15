extends Node
## Main SceneManager that handles adding scenes and transitions.

const FADE: String = "fade"

@onready var _fade_color_rect: ColorRect = find_child("fade")
@onready var _animation_player: AnimationPlayer = find_child("animation_player")
@onready var _in_transition: bool = false
@onready var _back_buffer: Array[Scenes.SceneName] = []
@onready var _back_buffer_limit: int = -1
@onready var _current_scene: Scenes.SceneName = Scenes.SceneName.NONE
@onready var _first_time: bool = true
@onready var _patterns: Dictionary = {}
@onready var _reserved_keys: Array = ["none"]

var _load_scene: String = "" ## Scene path that is currently loading
var _load_scene_enum: Scenes.SceneName = Scenes.SceneName.NONE ## Scene Enum of the scene that's currently loading
var _load_progress: Array = []
var _recorded_scene: Scenes.SceneName = Scenes.SceneName.NONE

signal load_finished
signal load_percent_changed(value: int)
signal scene_changed
signal fade_in_started
signal fade_out_started
signal fade_in_finished
signal fade_out_finished


class GeneralOptions:
	var color: Color = Color(0, 0, 0)
	var timeout: float = 0
	var clickable: bool = true
	var add_to_back: bool = true


func _current_scene_is_included(scene_file_path: String) -> bool:
	for include_path in Scenes.scenes._include_list:
		if scene_file_path.begins_with(include_path):
			return true
	return false


# sets current scene to starting point (used for `back` functionality)
func _set_current_scene() -> void:
	var scene_file_path: String = get_tree().current_scene.scene_file_path
	_current_scene = _get_scene_key_by_value(scene_file_path)

	# Don't do checks in the editor as the scenes loaded will not match the scene list
	if not Engine.is_editor_hint() and _current_scene == Scenes.SceneName.NONE:
		push_warning("loaded scene is ignored by scene manager, it means that you can not go back to this scene by 'back' key word.")


func _ready() -> void:
	set_process(false)
	_set_current_scene()


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
	if _back_buffer_limit == -1:
		_back_buffer.append(_current_scene)
	elif _back_buffer_limit > 0:
		if _back_buffer_limit <= len(_back_buffer):
			for i in range(len(_back_buffer) - _back_buffer_limit + 1):
				_back_buffer.pop_front()
			_back_buffer.append(_current_scene)
		else:
			_back_buffer.append(_current_scene)
	_current_scene = key


# Pops most recent added scene to `_back_buffer`
func _pop_stack() -> Scenes.SceneName:
	var pop = _back_buffer.pop_back()
	if pop:
		_current_scene = pop
	return _current_scene


# Changes scene to the previous scene
func _back() -> bool:
	var pop: Scenes.SceneName = _pop_stack()
	if pop:
		get_tree().change_scene_to_file(_get_scene_value(pop))
		return true
	return false


# Returns the scene key of the passed scene value (scene address)
func _get_scene_key_by_value(path: String) -> Scenes.SceneName:
	for key in Scenes.scenes[SceneManagerConstants.SCENE_DATA_KEY]:
		if Scenes.scenes[SceneManagerConstants.SCENE_DATA_KEY][key]["value"] == path:
			# Convert the string into an enum
			return SceneManagerUtils.get_enum_from_string(key)
			
	return Scenes.SceneName.NONE


# Returns the raw dictionary values for the scene
func _get_scene_value(scene: Scenes.SceneName) -> String:
	# The enums are normalized to have all caps, but the keys in the scenes may not have that,
	# do a string comparison with everything normalized.
	var scene_name: String = SceneManagerUtils.get_string_from_enum(scene)
	for key in Scenes.scenes[SceneManagerConstants.SCENE_DATA_KEY]:
		if scene_name == SceneManagerUtils.normalize_enum_string(key):
			return Scenes.scenes[SceneManagerConstants.SCENE_DATA_KEY][key]["value"]
	
	return ""


# Restart the currently loaded scene
func _refresh() -> bool:
	get_tree().change_scene_to_file(_get_scene_value(_current_scene))
	return true


# Checks different states of scene and make actual transitions happen
func _change_scene(scene: Scenes.SceneName, add_to_back: bool) -> bool:
	get_tree().change_scene_to_file(_get_scene_value(scene))
	if add_to_back:
		_append_stack(scene)
	return true


# Makes menu clickable or unclickable during transitions
func _set_clickable(clickable: bool) -> void:
	if clickable:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


# Sets color if timeout exists
func _timeout(timeout: float) -> bool:
	if timeout != 0:
		return true
	return false


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


## Limits how deep the scene manager is allowed to record previous scenes which
## affects in changing scene to `back`(previous scene) functionality.[br]
##
## allowed `input` values:[br]
## input = -1 => unlimited (default)[br]
## input =  0 => we can not go back to any previous scenes[br]
## input >  0 => we can go back to `input` or less previous scenes[br]
func set_back_limit(input: int) -> void:
	input = maxi(input, -1) # Clamp the value to a minimum of -1
	_back_buffer_limit = input
	if input == 0:
		_back_buffer.clear()
	elif input > 0:
		if input <= len(_back_buffer):
			for i in range(len(_back_buffer) - input):
				_back_buffer.pop_front()


## Resets the `_current_scene` and clears `_back_buffer`.
func reset_scene_manager() -> void:
	_set_current_scene()
	_back_buffer.clear()


## Creates options for common properties in transition.[br]
##
## add_to_back means that you can go back to the scene if you
## change scene to `back` scene
func create_general_options(color: Color = Color(0, 0, 0), timeout: float = 0.0, clickable: bool = true, add_to_back: bool = true) -> GeneralOptions:
	var options: GeneralOptions = GeneralOptions.new()
	options.color = color
	options.timeout = timeout
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
	var address = Scenes.scenes[SceneManagerConstants.SCENE_DATA_KEY][key]["value"]
	ResourceLoader.load_threaded_request(address, "", use_sub_threads, ResourceLoader.CACHE_MODE_REUSE)
	return ResourceLoader.load_threaded_get(address)


## Changes current scene to the specified scene.
func change_scene(scene: Scenes.SceneName, fade_out_time: float, fade_in_time: float, general_options: GeneralOptions) -> void:
	_first_time = false
	_set_in_transition()
	_set_clickable(general_options.clickable)

	if _fade_out(fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()

	if _change_scene(scene, general_options.add_to_back):
		await get_tree().node_added
		scene_changed.emit()
	
	if _timeout(general_options.timeout):
		await get_tree().create_timer(general_options.timeout).timeout
	
	if _fade_in(fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_clickable(true)
	_set_out_transition()


## Change scene with no effect.
func no_effect_change_scene(scene: Scenes.SceneName, hold_timeout: float = 0.0, add_to_back: bool = true) -> void:
	_first_time = false
	_set_in_transition()
	await get_tree().create_timer(hold_timeout).timeout
	if _change_scene(scene, add_to_back):
		await get_tree().node_added
	_set_out_transition()


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
func change_scene_to_existing_scene_in_scene_tree(fade_out_time: float, fade_in_time: float, general_options: GeneralOptions) -> void:
	_set_in_transition()
	_set_clickable(general_options.clickable)
	
	if _fade_out(fade_out_time):
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
	if general_options.add_to_back && found_key != Scenes.SceneName.NONE:
		_append_stack(found_key)

	# timeout and ...
	if _timeout(general_options.timeout):
		await get_tree().create_timer(general_options.timeout).timeout
	
	if _fade_in(fade_in_time):
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
func change_scene_to_loaded_scene(fade_out_time: float, fade_in_time: float, general_options: GeneralOptions) -> void:
	if _load_scene != "":
		var scene = ResourceLoader.load_threaded_get(_load_scene) as PackedScene
		if scene:
			change_scene(_load_scene_enum, fade_out_time, fade_in_time, general_options)


## Returns previous scene (scene before current scene)
func get_previous_scene() -> Scenes.SceneName:
	return _back_buffer[len(_back_buffer) - 1]


## Returns a specific previous scene at an exact index position
func get_previous_scene_at(index: int) -> Scenes.SceneName:
	if index < len(_back_buffer):
		return _back_buffer[index]
	return Scenes.SceneName.NONE


## Pops from the back stack and returns previous scene (scene before current scene)
func pop_previous_scene() -> Scenes.SceneName:
	return _pop_stack()


## Returns how many scenes there are in list of previous scenes.
func previous_scenes_length() -> int:
	return len(_back_buffer)


## Records a scene key to be used for loading scenes to know where to go after getting loaded
## into loading scene or just for next scene to know where to go next.
func set_recorded_scene(key: Scenes.SceneName) -> void:
	_recorded_scene = key


## Returns recorded scene
func get_recorded_scene() -> Scenes.SceneName:
	return _recorded_scene


## Pause (fadeout). You can resume afterwards.
func pause(fade_out_time: float, general_options: GeneralOptions) -> void:
	_set_in_transition()
	_set_clickable(general_options.clickable)
	
	if _fade_out(fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()


## Resume (fadein) after pause
func resume(fade_in_time: float, general_options: GeneralOptions) -> void:
	_set_clickable(general_options.clickable)
	
	if _fade_in(fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_out_transition()
	_set_clickable(true)
