class_name SceneManagerUtils
extends Node
## Helper class for the scene manager


## Returns the string form of the Scenes.SceneName enum.
##
## Note that this only works for unique enum values. If there are duplicate values
## assigned to the enums, then this won't work. However, since we control how the
## SceneName is created, this won't be an issue.
static func get_string_from_enum(scene: Scenes.SceneName) -> String:
	var index = Scenes.SceneName.values().find(scene)
	return Scenes.SceneName.keys()[index]


## Returns the Scenes.SceneName enum from the provided string.
##
## Returns Scenes.SceneName.NONE if the string doesn't match anything.
static func get_enum_from_string(key: String) -> Scenes.SceneName:
	var normalized := normalize_string(key)
	if normalized in Scenes.SceneName.keys():
		return Scenes.SceneName.get(normalized) as Scenes.SceneName
	
	return Scenes.SceneName.NONE


## Returns a string that is all caps with spaces replaced with underscores.
static func normalize_string(data: String) -> String:
	data = data.replace(" ", "_")
	return data.to_upper()
