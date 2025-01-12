@tool
class_name SceneLineEdit
extends LineEdit

@export var autocomplete: AutoCompleteAssistant


## Generates strings from the enum to feed into the autocomplete list
func generate_autocomplete() -> void:
	# Get all the strings from the Scenes.SceneName enum and find the closest match.
	var string_list: Array[String]
	string_list.append_array(Scenes.SceneName.keys())
	string_list.sort()
	autocomplete.load_terms(string_list, true)
