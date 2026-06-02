class_name BuiltinChips
extends RefCounted

const ChipDefinitionScript = preload("res://scripts/sim/chip_definition.gd")

static func create_standard_library() -> Dictionary:
	return {
		&"toggle": ChipDefinitionScript.new(
			&"toggle",
			"Logic Source",
			[
				{"name": &"OUT", "direction": &"out", "side": &"right"},
			],
			Color(0.18, 0.28, 0.38)
		),
		&"switch": ChipDefinitionScript.new(
			&"switch",
			"Pushbutton",
			[
				{"name": &"A", "direction": &"passive", "side": &"top"},
				{"name": &"B", "direction": &"passive", "side": &"bottom"},
			],
			Color(0.18, 0.28, 0.38)
		),
		&"led": ChipDefinitionScript.new(
			&"led",
			"LED",
			[
				{"name": &"IN", "direction": &"in", "side": &"left"},
				{"name": &"GND", "direction": &"passive", "side": &"bottom"},
			],
			Color(0.28, 0.16, 0.14)
		),
		&"power_5v": ChipDefinitionScript.new(
			&"power_5v",
			"5V",
			[
				{"name": &"OUT", "direction": &"out", "side": &"right"},
			],
			Color(0.70, 0.06, 0.05)
		),
		&"ground": ChipDefinitionScript.new(
			&"ground",
			"GND",
			[
				{"name": &"OUT", "direction": &"out", "side": &"right"},
			],
			Color(0.05, 0.05, 0.045)
		),
		&"ic_7400": ChipDefinitionScript.new(
			&"ic_7400",
			"74LS00 NAND",
			_dip14_quad_gate_pins(),
			Color(0.03, 0.035, 0.032)
		),
		&"ic_7404": ChipDefinitionScript.new(
			&"ic_7404",
			"74LS04 NOT",
			_dip14_hex_inverter_pins(),
			Color(0.03, 0.035, 0.032)
		),
		&"ic_7486": ChipDefinitionScript.new(
			&"ic_7486",
			"74LS86 XOR",
			_dip14_quad_gate_pins(),
			Color(0.03, 0.035, 0.032)
		),
		&"ic_7408": ChipDefinitionScript.new(
			&"ic_7408",
			"74LS08 AND",
			_dip14_quad_gate_pins(),
			Color(0.03, 0.035, 0.032)
		),
		&"ic_7432": ChipDefinitionScript.new(
			&"ic_7432",
			"74LS32 OR",
			_dip14_quad_gate_pins(),
			Color(0.03, 0.035, 0.032)
		),
		&"resistor_2k2": ChipDefinitionScript.new(
			&"resistor_2k2",
			"2.2K",
			[
				{"name": &"A", "direction": &"passive", "side": &"left"},
				{"name": &"B", "direction": &"passive", "side": &"right"},
			],
			Color(0.72, 0.46, 0.18)
		),
		&"resistor_220": ChipDefinitionScript.new(
			&"resistor_220",
			"220",
			[
				{"name": &"A", "direction": &"passive", "side": &"left"},
				{"name": &"B", "direction": &"passive", "side": &"right"},
			],
			Color(0.72, 0.46, 0.18)
		),
	}


static func _dip14_quad_gate_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	var output_pins := [&"3", &"6", &"8", &"11"]

	for pin_number: int in range(1, 8):
		var pin_name := StringName(str(pin_number))
		var direction := &"out" if output_pins.has(pin_name) else &"in"
		if pin_number == 7:
			direction = &"ground"
		pins.append({
			"name": pin_name,
			"direction": direction,
			"side": &"bottom",
		})

	for pin_number: int in range(14, 7, -1):
		var pin_name := StringName(str(pin_number))
		var direction := &"out" if output_pins.has(pin_name) else &"in"
		if pin_number == 14:
			direction = &"power"
		pins.append({
			"name": pin_name,
			"direction": direction,
			"side": &"top",
		})

	return pins


static func _dip14_hex_inverter_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	var output_pins := [&"2", &"4", &"6", &"8", &"10", &"12"]

	for pin_number: int in range(1, 8):
		var pin_name := StringName(str(pin_number))
		var direction := &"out" if output_pins.has(pin_name) else &"in"
		if pin_number == 7:
			direction = &"ground"
		pins.append({
			"name": pin_name,
			"direction": direction,
			"side": &"bottom",
		})

	for pin_number: int in range(14, 7, -1):
		var pin_name := StringName(str(pin_number))
		var direction := &"out" if output_pins.has(pin_name) else &"in"
		if pin_number == 14:
			direction = &"power"
		pins.append({
			"name": pin_name,
			"direction": direction,
			"side": &"top",
		})

	return pins
