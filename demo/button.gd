extends Button

@export var scene: Scenes.SceneName = Scenes.SceneName.NONE
@export var fade_out_speed: float = 1.0
@export var fade_in_speed: float = 1.0
@export var fade_out_pattern: String = "fade"
@export var fade_in_pattern: String = "fade"
@export var fade_out_smoothness: float = 0.1 # (float, 0, 1)
@export var fade_in_smoothness: float = 0.1 # (float, 0, 1)
@export var fade_out_inverted: bool = false
@export var fade_in_inverted: bool = false
@export var color: Color = Color(0, 0, 0)
@export var timeout: float = 0.0
@export var clickable: bool = false
@export var add_to_back: bool = true

@onready var fade_out_options := SceneManager.create_options(fade_out_speed, fade_out_pattern, fade_out_smoothness, fade_out_inverted)
@onready var fade_in_options := SceneManager.create_options(fade_in_speed, fade_in_pattern, fade_in_smoothness, fade_in_inverted)
@onready var general_options := SceneManager.create_general_options(color, timeout, clickable, add_to_back)


func _on_button_button_up():
	SceneManager.change_scene(scene, fade_out_options, fade_in_options, general_options)


func _on_reset_button_up():
	SceneManager.reset_scene_manager()


func _on_loading_scene_button_up():
	SceneManager.set_recorded_scene(scene)
	SceneManager.change_scene(Scenes.SceneName.LOADING, fade_out_options, fade_in_options, general_options)


func _on_loading_scene_initialization_button_up():
	SceneManager.set_recorded_scene(scene)
	SceneManager.change_scene(Scenes.SceneName.LOADING_WITH_INITIALIZATION, fade_out_options, fade_in_options, general_options)


func _on_pause_and_resume_button_up():
	await SceneManager.pause(fade_out_options, general_options)
	await get_tree().create_timer(3).timeout
	await SceneManager.resume(fade_in_options, general_options)


func _on_back_pressed() -> void:
	SceneManager.go_back()


func _on_reload_pressed() -> void:
	SceneManager.reload_current_scene()


func _on_exit_pressed() -> void:
	SceneManager.exit_game()
