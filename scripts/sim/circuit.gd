class_name Circuit
extends RefCounted

const ChipInstanceScript = preload("res://scripts/sim/chip_instance.gd")
const NetScript = preload("res://scripts/sim/net.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")

signal changed

var chips: Array = []
var nets: Array = []
# Physical jumper wires. Each entry is {"start": Hole, "end": Hole} where a Hole
# is either {"column": int, "row": int} for a terminal hole or
# {"rail": "side:polarity", "index": int} for a power-rail hole.
var wires: Array = []

var _next_chip_id := 1
# Maps hole_key(hole) -> occupant descriptor so no two pins or wire ends can
# ever share the same physical hole.
var _hole_occupants: Dictionary = {}


func add_net(net_label: String = "") -> int:
	var net := NetScript.new(nets.size(), net_label)
	nets.append(net)
	return net.id


# Returns the electrical bus a hole belongs to: a terminal column-half strip or
# a power rail. Holes on the same bus are electrically common.
func hole_bus_id(hole: Dictionary) -> String:
	if hole.has("rail"):
		return "rail:%s" % hole["rail"]
	if hole.has("column") and hole.has("row"):
		var half := "top" if int(hole["row"]) < 5 else "bottom"
		return "terminal:%d:%s" % [int(hole["column"]), half]
	return ""


# Unique address for a single physical hole, used for occupancy bookkeeping.
func hole_key(hole: Dictionary) -> String:
	if hole.has("rail"):
		return "rail:%s:%d" % [hole["rail"], int(hole.get("index", 0))]
	if hole.has("column") and hole.has("row"):
		return "%d:%d" % [int(hole["column"]), int(hole["row"])]
	return ""


func is_hole_free(hole: Dictionary) -> bool:
	var key := hole_key(hole)
	return not key.is_empty() and not _hole_occupants.has(key)


# Claims a hole for the given occupant. Returns false (without changing state)
# if the hole is already taken, which keeps wires and pins from overlapping.
func occupy_hole(hole: Dictionary, occupant) -> bool:
	var key := hole_key(hole)
	if key.is_empty():
		push_error("Cannot occupy an invalid hole.")
		return false
	if _hole_occupants.has(key):
		return false
	_hole_occupants[key] = occupant
	return true


# Returns the net wired to a bus, creating and labelling a fresh one if needed.
func bus_net(bus_id: String, net_label: String = "") -> int:
	if bus_id.is_empty():
		push_error("Cannot resolve an empty breadboard bus.")
		return -1

	var net_id := _net_id_for_bus(bus_id)
	if _is_valid_net_id(net_id):
		if nets[net_id].label.is_empty() and not net_label.is_empty():
			nets[net_id].label = net_label
		return net_id

	net_id = add_net(net_label)
	connect_bus(bus_id, net_id)
	return net_id


# Places a physical jumper between two holes, merging their buses onto one net.
# Both holes must be free; the endpoints are then marked occupied.
func add_wire(start_hole: Dictionary, end_hole: Dictionary, net_label: String = "") -> int:
	var start_bus := hole_bus_id(start_hole)
	var end_bus := hole_bus_id(end_hole)
	if start_bus.is_empty() or end_bus.is_empty():
		push_error("Cannot place a wire on an invalid hole.")
		return -1
	if hole_key(start_hole) == hole_key(end_hole):
		push_error("A wire cannot start and end in the same hole.")
		return -1
	if not is_hole_free(start_hole) or not is_hole_free(end_hole):
		push_error("Wire endpoint hole is already occupied.")
		return -1

	var net_id := connect_buses(start_bus, end_bus, net_label)
	if net_id < 0:
		return -1

	var wire := {"start": start_hole.duplicate(), "end": end_hole.duplicate()}
	occupy_hole(start_hole, wire)
	occupy_hole(end_hole, wire)
	wires.append(wire)
	changed.emit()
	return net_id


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


func connect_bus(bus_id: String, net_id: int) -> void:
	if net_id < 0 or net_id >= nets.size():
		push_error("Net %d does not exist." % net_id)
		return
	if _bus_connection_exists(net_id, bus_id):
		changed.emit()
		return

	nets[net_id].connections.append({"bus": bus_id})
	changed.emit()


func connect_bus_to_net(bus_id: String, net_id: int) -> int:
	if net_id < 0 or net_id >= nets.size():
		push_error("Net %d does not exist." % net_id)
		return -1

	var existing_net_id := _net_id_for_bus(bus_id)
	if _is_valid_net_id(existing_net_id) and existing_net_id != net_id:
		_merge_nets(net_id, existing_net_id)

	connect_bus(bus_id, net_id)
	return net_id


func connect_buses(bus_a: String, bus_b: String, net_label: String = "") -> int:
	if bus_a.is_empty() or bus_b.is_empty():
		push_error("Cannot wire an empty breadboard bus.")
		return -1

	var net_a := _net_id_for_bus(bus_a)
	var net_b := _net_id_for_bus(bus_b)
	var target_net_id := _joined_endpoint_net(net_a, net_b, net_label)
	if target_net_id < 0:
		return -1

	connect_bus_to_net(bus_a, target_net_id)
	connect_bus_to_net(bus_b, target_net_id)
	return target_net_id


func connect_pin_to_bus(chip, pin_name: StringName, bus_id: String, net_label: String = "") -> int:
	if chip == null:
		push_error("Cannot wire a null chip.")
		return -1
	if bus_id.is_empty():
		push_error("Cannot wire an empty breadboard bus.")
		return -1

	var pin_net_id: int = chip.pin_nets.get(pin_name, -1)
	var bus_net_id := _net_id_for_bus(bus_id)
	var target_net_id := _joined_endpoint_net(pin_net_id, bus_net_id, net_label)
	if target_net_id < 0:
		return -1

	connect_pin(chip, pin_name, target_net_id)
	connect_bus_to_net(bus_id, target_net_id)
	return target_net_id


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


func _joined_endpoint_net(net_a: int, net_b: int, net_label: String) -> int:
	var has_net_a := _is_valid_net_id(net_a)
	var has_net_b := _is_valid_net_id(net_b)

	if has_net_a and has_net_b:
		if net_a != net_b:
			_merge_nets(net_a, net_b)
		return net_a
	if has_net_a:
		return net_a
	if has_net_b:
		return net_b
	return add_net(net_label)


func read_pin(chip, pin_name: StringName) -> int:
	var net_id: int = chip.pin_nets.get(pin_name, -1)
	if net_id < 0 or net_id >= nets.size():
		return SignalValue.State.Z
	return nets[net_id].value


func drive_pin(chip, pin_name: StringName, value: int, weak: bool = false) -> void:
	var net_id: int = chip.pin_nets.get(pin_name, -1)
	if net_id < 0 or net_id >= nets.size():
		return
	if weak:
		nets[net_id].weak_drivers.append(value)
	else:
		nets[net_id].drivers.append(value)


func settle(max_iterations: int = 16) -> bool:
	# Recompute steady state purely from the active drivers. Clearing stale net
	# values first keeps bidirectional parts (like series resistors) from latching
	# onto a previous level and fighting the gate that now drives them.
	for net in nets:
		net.value = SignalValue.State.Z

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
		# Strong drivers win; weak pull resistors only matter on an otherwise
		# undriven net.
		net.value = SignalValue.resolve(net.drivers if not net.drivers.is_empty() else net.weak_drivers)


func _evaluate_chip(chip) -> void:
	match chip.definition.id:
		&"power_5v":
			drive_pin(chip, &"OUT", SignalValue.State.HIGH)
		&"ground":
			drive_pin(chip, &"OUT", SignalValue.State.LOW)
		&"toggle":
			drive_pin(chip, &"OUT", SignalValue.State.HIGH if chip.state.get("on", false) else SignalValue.State.LOW)
		&"switch":
			_evaluate_switch(chip)
		&"led":
			var value := read_pin(chip, &"IN")
			var has_ground := read_pin(chip, &"GND") == SignalValue.State.LOW
			chip.state["observed"] = value
			chip.state["lit"] = value == SignalValue.State.HIGH and has_ground
		&"resistor_2k2", &"resistor_220":
			_evaluate_resistor(chip)
		&"ic_7400":
			_evaluate_quad_nand(chip)
		&"ic_7404":
			_evaluate_hex_not(chip)
		&"ic_7486":
			_evaluate_quad_xor(chip)
		&"ic_7408":
			_evaluate_quad_and(chip)
		&"ic_7432":
			_evaluate_quad_or(chip)


func _is_valid_net_id(net_id: int) -> bool:
	return net_id >= 0 and net_id < nets.size()


func _evaluate_resistor(chip) -> void:
	# A resistor passes a settled logic level between its legs, but only weakly:
	# a strong source on either side overrides it (so a pull-down loses to VCC).
	# Propagating only definite HIGH/LOW (never floating Z or unknown X) also stops
	# the two legs from echoing transient states back and forth and oscillating.
	var a_value := read_pin(chip, &"A")
	var b_value := read_pin(chip, &"B")
	if a_value == SignalValue.State.LOW or a_value == SignalValue.State.HIGH:
		drive_pin(chip, &"B", a_value, true)
	if b_value == SignalValue.State.LOW or b_value == SignalValue.State.HIGH:
		drive_pin(chip, &"A", b_value, true)


# A pushbutton: while latched on it closes, conducting a definite level between
# its two legs as a strong (ideal) contact; released, it is an open circuit.
func _evaluate_switch(chip) -> void:
	if not chip.state.get("on", false):
		return

	var a_value := read_pin(chip, &"A")
	var b_value := read_pin(chip, &"B")
	if a_value == SignalValue.State.LOW or a_value == SignalValue.State.HIGH:
		drive_pin(chip, &"B", a_value)
	if b_value == SignalValue.State.LOW or b_value == SignalValue.State.HIGH:
		drive_pin(chip, &"A", b_value)


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


func _bus_connection_exists(net_id: int, bus_id: String) -> bool:
	if not _is_valid_net_id(net_id):
		return false

	for connection: Dictionary in nets[net_id].connections:
		if connection.get("bus", "") == bus_id:
			return true
	return false


func net_id_for_bus(bus_id: String) -> int:
	return _net_id_for_bus(bus_id)


func _net_id_for_bus(bus_id: String) -> int:
	for net in nets:
		if _bus_connection_exists(net.id, bus_id):
			return net.id
	return -1


func _merge_nets(target_net_id: int, source_net_id: int) -> void:
	if not _is_valid_net_id(target_net_id) or not _is_valid_net_id(source_net_id):
		return
	if target_net_id == source_net_id:
		return

	var source_connections: Array[Dictionary] = nets[source_net_id].connections.duplicate()
	for connection: Dictionary in source_connections:
		if connection.has("bus"):
			connect_bus(connection["bus"], target_net_id)
			continue

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


func _has_valid_dip14_power(chip) -> bool:
	return read_pin(chip, &"14") == SignalValue.State.HIGH and read_pin(chip, &"7") == SignalValue.State.LOW


func _evaluate_quad_nand(chip) -> void:
	if not _has_valid_dip14_power(chip):
		return

	drive_pin(chip, &"3", _eval_nand(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_nand(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_nand(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_nand(read_pin(chip, &"12"), read_pin(chip, &"13")))


func _evaluate_hex_not(chip) -> void:
	if not _has_valid_dip14_power(chip):
		return

	drive_pin(chip, &"2", _eval_not(read_pin(chip, &"1")))
	drive_pin(chip, &"4", _eval_not(read_pin(chip, &"3")))
	drive_pin(chip, &"6", _eval_not(read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_not(read_pin(chip, &"9")))
	drive_pin(chip, &"10", _eval_not(read_pin(chip, &"11")))
	drive_pin(chip, &"12", _eval_not(read_pin(chip, &"13")))


func _evaluate_quad_xor(chip) -> void:
	if not _has_valid_dip14_power(chip):
		return

	drive_pin(chip, &"3", _eval_xor(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_xor(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_xor(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_xor(read_pin(chip, &"12"), read_pin(chip, &"13")))


func _evaluate_quad_and(chip) -> void:
	if not _has_valid_dip14_power(chip):
		return

	drive_pin(chip, &"3", _eval_and(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_and(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_and(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_and(read_pin(chip, &"12"), read_pin(chip, &"13")))


func _evaluate_quad_or(chip) -> void:
	if not _has_valid_dip14_power(chip):
		return

	drive_pin(chip, &"3", _eval_or(read_pin(chip, &"1"), read_pin(chip, &"2")))
	drive_pin(chip, &"6", _eval_or(read_pin(chip, &"4"), read_pin(chip, &"5")))
	drive_pin(chip, &"8", _eval_or(read_pin(chip, &"9"), read_pin(chip, &"10")))
	drive_pin(chip, &"11", _eval_or(read_pin(chip, &"12"), read_pin(chip, &"13")))
