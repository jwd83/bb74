class_name Circuit
extends RefCounted

const ChipInstanceScript = preload("res://scripts/sim/chip_instance.gd")
const NetScript = preload("res://scripts/sim/net.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")

signal changed

var chips: Array = []
var nets: Array = []

var _next_chip_id := 1


func add_net(net_label: String = "") -> int:
	var net := NetScript.new(nets.size(), net_label)
	nets.append(net)
	return net.id


func add_chip(definition, position: Vector2i, label: String = ""):
	var chip := ChipInstanceScript.new(_next_chip_id, definition, position, label)
	_next_chip_id += 1
	chips.append(chip)
	return chip


func connect_pin(chip, pin_name: StringName, net_id: int) -> void:
	if net_id < 0 or net_id >= nets.size():
		push_error("Net %d does not exist." % net_id)
		return

	chip.pin_nets[pin_name] = net_id
	nets[net_id].connections.append({"chip": chip, "pin": pin_name})


func read_pin(chip, pin_name: StringName) -> int:
	var net_id: int = chip.pin_nets.get(pin_name, -1)
	if net_id < 0 or net_id >= nets.size():
		return SignalValue.State.Z
	return nets[net_id].value


func drive_pin(chip, pin_name: StringName, value: int) -> void:
	var net_id: int = chip.pin_nets.get(pin_name, -1)
	if net_id < 0 or net_id >= nets.size():
		return
	nets[net_id].drivers.append(value)


func settle(max_iterations: int = 16) -> bool:
	for _iteration in range(max_iterations):
		var previous := _net_values()
		_evaluate_once()
		if _net_values() == previous:
			changed.emit()
			return true

	changed.emit()
	return false


func _net_values() -> Array[int]:
	var values: Array[int] = []
	for net in nets:
		values.append(net.value)
	return values


func _evaluate_once() -> void:
	for net in nets:
		net.reset_drivers()

	for chip in chips:
		_evaluate_chip(chip)

	for net in nets:
		net.value = SignalValue.resolve(net.drivers)


func _evaluate_chip(chip) -> void:
	match chip.definition.id:
		&"toggle":
			drive_pin(chip, &"OUT", SignalValue.State.HIGH if chip.state.get("on", false) else SignalValue.State.LOW)
		&"led":
			var value := read_pin(chip, &"IN")
			chip.state["observed"] = value
			chip.state["lit"] = value == SignalValue.State.HIGH
		&"nand":
			drive_pin(chip, &"Y", _eval_nand(read_pin(chip, &"A"), read_pin(chip, &"B")))
		&"not":
			drive_pin(chip, &"Y", _eval_not(read_pin(chip, &"A")))
		&"and":
			drive_pin(chip, &"Y", _eval_and(read_pin(chip, &"A"), read_pin(chip, &"B")))
		&"or":
			drive_pin(chip, &"Y", _eval_or(read_pin(chip, &"A"), read_pin(chip, &"B")))
		&"xor":
			drive_pin(chip, &"Y", _eval_xor(read_pin(chip, &"A"), read_pin(chip, &"B")))
		&"ic_7486":
			_evaluate_quad_xor(chip)
		&"ic_7408":
			_evaluate_quad_and(chip)
		&"ic_7432":
			_evaluate_quad_or(chip)


func _eval_not(value: int) -> int:
	if value == SignalValue.State.LOW:
		return SignalValue.State.HIGH
	if value == SignalValue.State.HIGH:
		return SignalValue.State.LOW
	return SignalValue.State.X


func _eval_nand(a: int, b: int) -> int:
	var and_value := _eval_and(a, b)
	if and_value == SignalValue.State.X:
		return SignalValue.State.X
	return _eval_not(and_value)


func _eval_and(a: int, b: int) -> int:
	if a == SignalValue.State.LOW or b == SignalValue.State.LOW:
		return SignalValue.State.LOW
	if a == SignalValue.State.HIGH and b == SignalValue.State.HIGH:
		return SignalValue.State.HIGH
	return SignalValue.State.X


func _eval_or(a: int, b: int) -> int:
	if a == SignalValue.State.HIGH or b == SignalValue.State.HIGH:
		return SignalValue.State.HIGH
	if a == SignalValue.State.LOW and b == SignalValue.State.LOW:
		return SignalValue.State.LOW
	return SignalValue.State.X


func _eval_xor(a: int, b: int) -> int:
	if a in [SignalValue.State.Z, SignalValue.State.X] or b in [SignalValue.State.Z, SignalValue.State.X]:
		return SignalValue.State.X
	return SignalValue.State.HIGH if a != b else SignalValue.State.LOW


func _evaluate_quad_xor(chip) -> void:
	drive_pin(chip, &"3", _eval_xor(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_xor(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_xor(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_xor(read_pin(chip, &"12"), read_pin(chip, &"13")))


func _evaluate_quad_and(chip) -> void:
	drive_pin(chip, &"3", _eval_and(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_and(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_and(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_and(read_pin(chip, &"12"), read_pin(chip, &"13")))


func _evaluate_quad_or(chip) -> void:
	drive_pin(chip, &"3", _eval_or(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_or(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_or(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_or(read_pin(chip, &"12"), read_pin(chip, &"13")))
