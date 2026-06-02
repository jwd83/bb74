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
	changed.emit()
	return chip


func connect_pin(chip, pin_name: StringName, net_id: int) -> void:
	if chip == null:
		push_error("Cannot connect a null chip.")
		return
	if net_id < 0 or net_id >= nets.size():
		push_error("Net %d does not exist." % net_id)
		return

	var previous_net_id: int = chip.pin_nets.get(pin_name, -1)
	if _is_valid_net_id(previous_net_id):
		if previous_net_id == net_id:
			_ensure_connection(net_id, chip, pin_name)
			changed.emit()
			return
		_remove_connection(previous_net_id, chip, pin_name)

	chip.pin_nets[pin_name] = net_id
	_ensure_connection(net_id, chip, pin_name)
	changed.emit()


func connect_pins(chip_a, pin_a: StringName, chip_b, pin_b: StringName, net_label: String = "") -> int:
	if chip_a == null or chip_b == null:
		push_error("Cannot wire null chips.")
		return -1

	var net_a: int = chip_a.pin_nets.get(pin_a, -1)
	var net_b: int = chip_b.pin_nets.get(pin_b, -1)
	var has_net_a := _is_valid_net_id(net_a)
	var has_net_b := _is_valid_net_id(net_b)

	if has_net_a and has_net_b:
		if net_a != net_b:
			_merge_nets(net_a, net_b)
		else:
			changed.emit()
		return net_a

	var target_net_id := -1
	if has_net_a:
		target_net_id = net_a
	elif has_net_b:
		target_net_id = net_b
	else:
		target_net_id = add_net(net_label)

	connect_pin(chip_a, pin_a, target_net_id)
	connect_pin(chip_b, pin_b, target_net_id)
	return target_net_id


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


func _is_valid_net_id(net_id: int) -> bool:
	return net_id >= 0 and net_id < nets.size()


func _ensure_connection(net_id: int, chip, pin_name: StringName) -> void:
	if _connection_exists(net_id, chip, pin_name):
		return
	nets[net_id].connections.append({"chip": chip, "pin": pin_name})


func _remove_connection(net_id: int, chip, pin_name: StringName) -> void:
	if not _is_valid_net_id(net_id):
		return

	var connections: Array[Dictionary] = nets[net_id].connections
	for index: int in range(connections.size() - 1, -1, -1):
		if _connection_matches(connections[index], chip, pin_name):
			connections.remove_at(index)


func _connection_exists(net_id: int, chip, pin_name: StringName) -> bool:
	if not _is_valid_net_id(net_id):
		return false

	for connection: Dictionary in nets[net_id].connections:
		if _connection_matches(connection, chip, pin_name):
			return true
	return false


func _connection_matches(connection: Dictionary, chip, pin_name: StringName) -> bool:
	return connection.get("chip") == chip and connection.get("pin") == pin_name


func _merge_nets(target_net_id: int, source_net_id: int) -> void:
	if not _is_valid_net_id(target_net_id) or not _is_valid_net_id(source_net_id):
		return
	if target_net_id == source_net_id:
		return

	var source_connections: Array[Dictionary] = nets[source_net_id].connections.duplicate()
	for connection: Dictionary in source_connections:
		var chip = connection.get("chip")
		var pin_name: StringName = connection.get("pin")
		if chip == null:
			continue
		chip.pin_nets[pin_name] = target_net_id
		_ensure_connection(target_net_id, chip, pin_name)

	nets[source_net_id].connections.clear()
	if nets[target_net_id].label.is_empty() and not nets[source_net_id].label.is_empty():
		nets[target_net_id].label = nets[source_net_id].label
	changed.emit()


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
