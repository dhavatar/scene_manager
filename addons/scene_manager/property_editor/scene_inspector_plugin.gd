@tool
extends EditorInspectorPlugin

var SceneEditorProperty = preload("res://addons/scene_manager/property_editor/scene_editor_property.gd")


func _can_handle(object):
	# We support all objects.
	return true


func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	# We handle properties of SceneResource
	if hint_string == "SceneResource":
		# Create an instance of the custom property editor and register
		# it to a specific property path.
		add_property_editor(name, SceneEditorProperty.new())
		return true
	
	return false
