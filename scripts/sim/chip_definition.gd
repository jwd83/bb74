class_name ChipDefinition
extends RefCounted

var id: StringName
var display_name: String
var pins: Array[Dictionary]
var tint: Color


func _init(
	definition_id: StringName = &"",
	definition_name: String = "",
	pin_list: Array[Dictionary] = [],
	definition_tint: Color = Color(0.16, 0.18, 0.20)
) -> void:
	id = definition_id
	display_name = definition_name
	pins = pin_list
	tint = definition_tint


func get_pin(pin_name: StringName) -> Dictionary:
	for pin: Dictionary in pins:
		if pin.get("name") == pin_name:
			return pin
	return {}


func pin_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for pin: Dictionary in pins:
		names.append(pin.get("name"))
	return names
