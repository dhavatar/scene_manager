extends Control

# Nodes
@onready var progress: ProgressBar = find_child("Progress")
@onready var loading: AnimatedSprite2D = find_child("Loading")
@onready var next: Button = find_child("Next")


func _ready():
	SceneManager.load_percent_changed.connect(percent_changed)
	SceneManager.load_finished.connect(loading_finished)
	SceneManager.load_scene_interactive(SceneManager.get_recorded_scene())


func percent_changed(number: int) -> void:
	progress.value = number


func loading_finished() -> void:
	loading.visible = false
	next.visible = true


func _on_next_button_up():
	var general_options := SceneManager.create_load_options()
	SceneManager.change_scene_to_loaded_scene(general_options)
