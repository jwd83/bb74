class_name ChipInstance
extends RefCounted

var id: int
var definition
var label: String
var position: Vector2i
var pin_nets: Dictionary = {}
var state: Dictionary = {}


func _init(
	instance_id: int = 0,
	chip_definition = null,
	board_position: Vector2i = Vector2i.ZERO,
	instance_label: String = ""
) -> void:
	id = instance_id
	definition = chip_definition
	position = board_position
	label = instance_label
