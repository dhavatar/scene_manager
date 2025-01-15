@tool
class_name SceneResource
extends Resource
## Custom resource for the editor property to allow it to have a custom inspector.

@export var string_value: String
@export var scene_value: Scenes.SceneName = Scenes.SceneName.NONE


## Sets the text for the resource, which will automatically find the corresponding
## [Scenes.SceneName] enum.
func set_text(text: String) -> void:
    if string_value != text:
        string_value = text
        scene_value = SceneManagerUtils.get_enum_from_string(text)
        emit_changed()


## ToString override to print a more helpful string information for the resource.
func _to_string() -> String:
    return "String: {0}, Scene: {1}".format([string_value, scene_value])
