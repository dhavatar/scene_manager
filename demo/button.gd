extends Button

@export var scene: SceneResource
@export var fade_out_speed: float = 1.0
@export var fade_in_speed: float = 1.0
@export var color: Color = Color(0, 0, 0)
@export var timeout: float = 0.0
@export var clickable: bool = false
@export var add_to_back: bool = true

@onready var general_options := SceneManager.create_general_options(color, timeout, clickable, add_to_back)


func _on_button_button_up():
	SceneManager.change_scene(scene.scene_value, fade_out_speed, fade_in_speed, general_options)


func _on_reset_button_up():
	SceneManager.reset_scene_manager()


func _on_loading_scene_button_up():
	SceneManager.set_recorded_scene(scene.scene_value)
	SceneManager.change_scene(Scenes.SceneName.LOADING, fade_out_speed, fade_in_speed, general_options)


func _on_loading_scene_initialization_button_up():
	SceneManager.set_recorded_scene(scene.scene_value)
	SceneManager.change_scene(Scenes.SceneName.LOADING_WITH_INITIALIZATION, fade_out_speed, fade_in_speed, general_options)


func _on_pause_and_resume_button_up():
	await SceneManager.pause(fade_out_speed, general_options)
	await get_tree().create_timer(3).timeout
	await SceneManager.resume(fade_in_speed, general_options)


func _on_back_pressed() -> void:
	SceneManager.go_back()


func _on_reload_pressed() -> void:
	SceneManager.reload_current_scene()


func _on_exit_pressed() -> void:
	SceneManager.exit_game()
