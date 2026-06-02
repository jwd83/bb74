extends SceneTree

const BuiltinChipsScript = preload("res://scripts/sim/builtin_chips.gd")
const CircuitScript = preload("res://scripts/sim/circuit.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_signal_resolution()
	_test_binary_gate_truth_tables()
	_test_not_truth_table()
	_test_unpowered_ic_outputs_z()
	_test_led_requires_ground()
	_test_resistor_bridges_signal_to_led()
	_test_conflicting_toggle_drivers()
	_test_connect_pin_reassigns_cleanly()
	_test_bus_connections_are_net_members()
	_test_connect_pin_to_bus_joins_breadboard_strip()
	_test_connect_buses_merge_existing_strip_nets()
	_test_connect_pins_merges_existing_nets()
	_test_full_adder_ic_truth_table()

	if _failures.is_empty():
		print("sim_tests: all tests passed")
		quit(0)
		return

	for failure: String in _failures:
		printerr(failure)
	printerr("sim_tests: %d failure(s)" % _failures.size())
	quit(1)


func _test_signal_resolution() -> void:
	_assert_equal(SignalValue.resolve([]), SignalValue.State.Z, "no drivers resolve to Z")
	_assert_equal(SignalValue.resolve([SignalValue.State.LOW]), SignalValue.State.LOW, "single low driver resolves to 0")
	_assert_equal(SignalValue.resolve([SignalValue.State.HIGH]), SignalValue.State.HIGH, "single high driver resolves to 1")
	_assert_equal(SignalValue.resolve([SignalValue.State.LOW, SignalValue.State.LOW]), SignalValue.State.LOW, "matching low drivers resolve to 0")
	_assert_equal(SignalValue.resolve([SignalValue.State.HIGH, SignalValue.State.HIGH]), SignalValue.State.HIGH, "matching high drivers resolve to 1")
	_assert_equal(SignalValue.resolve([SignalValue.State.LOW, SignalValue.State.HIGH]), SignalValue.State.X, "conflicting drivers resolve to X")
	_assert_equal(SignalValue.resolve([SignalValue.State.X]), SignalValue.State.X, "invalid driver resolves to X")


func _test_binary_gate_truth_tables() -> void:
	var lows_and_highs: Array[Dictionary] = [
		{"a": false, "b": false},
		{"a": false, "b": true},
		{"a": true, "b": false},
		{"a": true, "b": true},
	]

	var expected: Dictionary = {
		&"ic_7400": [SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.LOW],
		&"ic_7408": [SignalValue.State.LOW, SignalValue.State.LOW, SignalValue.State.LOW, SignalValue.State.HIGH],
		&"ic_7432": [SignalValue.State.LOW, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.HIGH],
		&"ic_7486": [SignalValue.State.LOW, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.LOW],
	}

	for chip_id: StringName in expected:
		for index: int in range(lows_and_highs.size()):
			var row: Dictionary = lows_and_highs[index]
			var output: int = _simulate_binary_gate(chip_id, row["a"], row["b"])
			_assert_equal(
				output,
				expected[chip_id][index],
				"%s(%s, %s)" % [chip_id, _bit_label(row["a"]), _bit_label(row["b"])]
			)


func _test_not_truth_table() -> void:
	_assert_equal(_simulate_unary_gate(&"ic_7404", false), SignalValue.State.HIGH, "not(0)")
	_assert_equal(_simulate_unary_gate(&"ic_7404", true), SignalValue.State.LOW, "not(1)")


func _test_unpowered_ic_outputs_z() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input_a = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "B")
	var gate = circuit.add_chip(library[&"ic_7400"], Vector2i(2, 0), "7400")
	var net_a: int = circuit.add_net("A")
	var net_b: int = circuit.add_net("B")
	var net_y: int = circuit.add_net("Y")

	input_a.state["on"] = true
	input_b.state["on"] = true
	circuit.connect_pin(input_a, &"OUT", net_a)
	circuit.connect_pin(gate, &"1", net_a)
	circuit.connect_pin(input_b, &"OUT", net_b)
	circuit.connect_pin(gate, &"2", net_b)
	circuit.connect_pin(gate, &"3", net_y)

	_assert_true(circuit.settle(), "unpowered IC circuit settled")
	_assert_equal(circuit.nets[net_y].value, SignalValue.State.Z, "unpowered 74LS00 output floats")


func _test_led_requires_ground() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var power = circuit.add_chip(library[&"power_5v"], Vector2i.ZERO, "5V")
	var led = circuit.add_chip(library[&"led"], Vector2i.ONE, "LED")
	var net_high: int = circuit.add_net("HIGH")

	circuit.connect_pin(power, &"OUT", net_high)
	circuit.connect_pin(led, &"IN", net_high)

	_assert_true(circuit.settle(), "floating LED circuit settled")
	_assert_equal(circuit.nets[net_high].value, SignalValue.State.HIGH, "power terminal drives LED input")
	_assert_false(led.state.get("lit", false), "LED without ground stays off")


func _test_resistor_bridges_signal_to_led() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var power = circuit.add_chip(library[&"power_5v"], Vector2i.ZERO, "5V")
	var ground = circuit.add_chip(library[&"ground"], Vector2i(1, 0), "GND")
	var resistor = circuit.add_chip(library[&"resistor_220"], Vector2i(2, 0), "R1")
	var led = circuit.add_chip(library[&"led"], Vector2i(3, 0), "LED")
	var source_net: int = circuit.add_net("SOURCE")
	var led_net: int = circuit.add_net("LED")
	var ground_net: int = circuit.add_net("GND")

	circuit.connect_pin(power, &"OUT", source_net)
	circuit.connect_pin(resistor, &"A", source_net)
	circuit.connect_pin(resistor, &"B", led_net)
	circuit.connect_pin(led, &"IN", led_net)
	circuit.connect_pin(ground, &"OUT", ground_net)
	circuit.connect_pin(led, &"GND", ground_net)

	_assert_true(circuit.settle(), "series resistor LED circuit settled")
	_assert_equal(circuit.nets[led_net].value, SignalValue.State.HIGH, "resistor bridges source signal to LED input")
	_assert_true(led.state.get("lit", false), "LED lights through series resistor")


func _test_conflicting_toggle_drivers() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var low_toggle = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Low")
	var high_toggle = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "High")
	var net_id: int = circuit.add_net("BUS")

	low_toggle.state["on"] = false
	high_toggle.state["on"] = true
	circuit.connect_pin(low_toggle, &"OUT", net_id)
	circuit.connect_pin(high_toggle, &"OUT", net_id)

	_assert_true(circuit.settle(), "conflicting driver circuit settled")
	_assert_equal(circuit.nets[net_id].value, SignalValue.State.X, "conflicting toggle drivers produce X")


func _test_connect_pin_reassigns_cleanly() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var first_net: int = circuit.add_net("A")
	var second_net: int = circuit.add_net("B")

	circuit.connect_pin(input, &"OUT", first_net)
	circuit.connect_pin(input, &"OUT", second_net)

	_assert_equal(circuit.nets[first_net].connections.size(), 0, "old net loses reassigned pin")
	_assert_equal(circuit.nets[second_net].connections.size(), 1, "new net keeps reassigned pin")
	_assert_equal(input.pin_nets[&"OUT"], second_net, "pin records reassigned net")


func _test_bus_connections_are_net_members() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var led = circuit.add_chip(library[&"led"], Vector2i.ONE, "Probe")
	var first_net: int = circuit.add_net("A")
	var second_net: int = circuit.add_net("B")

	circuit.connect_pin(input, &"OUT", first_net)
	circuit.connect_bus("terminal:10:bottom", first_net)
	circuit.connect_pin(led, &"IN", second_net)
	circuit.connect_bus("terminal:11:bottom", second_net)
	circuit.connect_pins(input, &"OUT", led, &"IN", "BUS")

	_assert_equal(circuit.nets[second_net].connections.size(), 0, "merged source net clears bus connections")
	_assert_true(_net_has_bus(circuit, first_net, "terminal:10:bottom"), "target net keeps original bus")
	_assert_true(_net_has_bus(circuit, first_net, "terminal:11:bottom"), "target net gains merged bus")


func _test_connect_pin_to_bus_joins_breadboard_strip() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var led = circuit.add_chip(library[&"led"], Vector2i.ONE, "Probe")
	var bus_id := "terminal:12:bottom"

	input.state["on"] = true
	var input_net: int = circuit.connect_pin_to_bus(input, &"OUT", bus_id, "WIRE")
	var led_net: int = circuit.connect_pin_to_bus(led, &"IN", bus_id, "WIRE")

	_assert_equal(led_net, input_net, "pin-to-bus reuses existing strip net")
	_assert_true(_net_has_bus(circuit, input_net, bus_id), "pin-to-bus net includes strip bus")
	_assert_true(circuit.settle(), "pin-to-bus circuit settled")
	_assert_equal(circuit.read_pin(led, &"IN"), SignalValue.State.HIGH, "strip bus carries input signal to probe")


func _test_connect_buses_merge_existing_strip_nets() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var led = circuit.add_chip(library[&"led"], Vector2i.ONE, "Probe")
	var source_bus := "terminal:5:bottom"
	var target_bus := "rail:top:plus"
	var source_net: int = circuit.add_net("SOURCE")
	var target_net: int = circuit.add_net("TARGET")

	input.state["on"] = true
	circuit.connect_pin(input, &"OUT", source_net)
	circuit.connect_bus(source_bus, source_net)
	circuit.connect_pin(led, &"IN", target_net)
	circuit.connect_bus(target_bus, target_net)
	var joined_net: int = circuit.connect_buses(source_bus, target_bus, "JUMPER")

	_assert_equal(joined_net, source_net, "bus jumper keeps first bus net as target")
	_assert_equal(circuit.nets[target_net].connections.size(), 0, "bus jumper clears merged source net")
	_assert_true(_net_has_bus(circuit, source_net, source_bus), "bus jumper keeps source bus")
	_assert_true(_net_has_bus(circuit, source_net, target_bus), "bus jumper gains target bus")
	_assert_true(circuit.settle(), "bus jumper circuit settled")
	_assert_equal(circuit.read_pin(led, &"IN"), SignalValue.State.HIGH, "bus jumper carries source signal")


func _test_connect_pins_merges_existing_nets() -> void:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var low_toggle = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Low")
	var high_toggle = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "High")
	var led = circuit.add_chip(library[&"led"], Vector2i(2, 0), "Probe")
	var low_net: int = circuit.add_net("LOW")
	var high_net: int = circuit.add_net("HIGH")

	low_toggle.state["on"] = false
	high_toggle.state["on"] = true
	circuit.connect_pin(low_toggle, &"OUT", low_net)
	circuit.connect_pin(led, &"IN", low_net)
	circuit.connect_pin(high_toggle, &"OUT", high_net)
	circuit.connect_pins(high_toggle, &"OUT", led, &"IN", "BUS")

	_assert_equal(circuit.nets[low_net].connections.size(), 0, "merged source net is emptied")
	_assert_equal(led.pin_nets[&"IN"], high_net, "merged source pin now points at target net")
	_assert_true(circuit.settle(), "merged interactive wire circuit settled")
	_assert_equal(circuit.nets[high_net].value, SignalValue.State.X, "merged opposing drivers conflict")


func _test_full_adder_ic_truth_table() -> void:
	var rows: Array[Dictionary] = [
		{"a": false, "b": false, "cin": false, "sum": false, "cout": false},
		{"a": false, "b": false, "cin": true, "sum": true, "cout": false},
		{"a": false, "b": true, "cin": false, "sum": true, "cout": false},
		{"a": false, "b": true, "cin": true, "sum": false, "cout": true},
		{"a": true, "b": false, "cin": false, "sum": true, "cout": false},
		{"a": true, "b": false, "cin": true, "sum": false, "cout": true},
		{"a": true, "b": true, "cin": false, "sum": false, "cout": true},
		{"a": true, "b": true, "cin": true, "sum": true, "cout": true},
	]

	for row: Dictionary in rows:
		var result: Dictionary = _simulate_full_adder(row["a"], row["b"], row["cin"])
		var label := "full adder A=%s B=%s Cin=%s" % [
			_bit_label(row["a"]),
			_bit_label(row["b"]),
			_bit_label(row["cin"]),
		]
		_assert_equal(result["sum"], SignalValue.State.HIGH if row["sum"] else SignalValue.State.LOW, "%s SUM" % label)
		_assert_equal(result["cout"], SignalValue.State.HIGH if row["cout"] else SignalValue.State.LOW, "%s Cout" % label)


func _add_power_rails(circuit) -> Dictionary:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var power = circuit.add_chip(library[&"power_5v"], Vector2i(-2, 0), "5V")
	var ground = circuit.add_chip(library[&"ground"], Vector2i(-2, 1), "GND")
	var net_vcc: int = circuit.add_net("VCC")
	var net_gnd: int = circuit.add_net("GND")

	circuit.connect_pin(power, &"OUT", net_vcc)
	circuit.connect_pin(ground, &"OUT", net_gnd)

	return {"VCC": net_vcc, "GND": net_gnd}


func _simulate_unary_gate(chip_id: StringName, input_on: bool) -> int:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var rails := _add_power_rails(circuit)
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var gate = circuit.add_chip(library[chip_id], Vector2i.ONE, "Gate")
	var input_net: int = circuit.add_net("A")
	var output_net: int = circuit.add_net("Y")

	input.state["on"] = input_on
	circuit.connect_pin(input, &"OUT", input_net)
	circuit.connect_pin(gate, &"14", rails["VCC"])
	circuit.connect_pin(gate, &"7", rails["GND"])
	circuit.connect_pin(gate, &"1", input_net)
	circuit.connect_pin(gate, &"2", output_net)

	_assert_true(circuit.settle(), "%s settled" % chip_id)
	return circuit.nets[output_net].value


func _simulate_binary_gate(chip_id: StringName, input_a_on: bool, input_b_on: bool) -> int:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var rails := _add_power_rails(circuit)
	var input_a = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "B")
	var gate = circuit.add_chip(library[chip_id], Vector2i(2, 0), "Gate")
	var net_a: int = circuit.add_net("A")
	var net_b: int = circuit.add_net("B")
	var net_y: int = circuit.add_net("Y")

	input_a.state["on"] = input_a_on
	input_b.state["on"] = input_b_on
	circuit.connect_pin(input_a, &"OUT", net_a)
	circuit.connect_pin(gate, &"14", rails["VCC"])
	circuit.connect_pin(gate, &"7", rails["GND"])
	circuit.connect_pin(gate, &"1", net_a)
	circuit.connect_pin(input_b, &"OUT", net_b)
	circuit.connect_pin(gate, &"2", net_b)
	circuit.connect_pin(gate, &"3", net_y)

	_assert_true(circuit.settle(), "%s settled" % chip_id)
	return circuit.nets[net_y].value


func _simulate_full_adder(input_a_on: bool, input_b_on: bool, input_cin_on: bool) -> Dictionary:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var rails := _add_power_rails(circuit)
	var input_a = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "B")
	var input_cin = circuit.add_chip(library[&"toggle"], Vector2i(2, 0), "Cin")
	var xor_chip = circuit.add_chip(library[&"ic_7486"], Vector2i(4, 0), "7486")
	var and_chip = circuit.add_chip(library[&"ic_7408"], Vector2i(6, 0), "7408")
	var or_chip = circuit.add_chip(library[&"ic_7432"], Vector2i(8, 0), "7432")
	var net_a: int = circuit.add_net("A")
	var net_b: int = circuit.add_net("B")
	var net_cin: int = circuit.add_net("Cin")
	var net_a_xor_b: int = circuit.add_net("A xor B")
	var net_a_and_b: int = circuit.add_net("A and B")
	var net_xor_and_cin: int = circuit.add_net("(A xor B) and Cin")
	var net_sum: int = circuit.add_net("SUM")
	var net_cout: int = circuit.add_net("Cout")

	input_a.state["on"] = input_a_on
	input_b.state["on"] = input_b_on
	input_cin.state["on"] = input_cin_on

	circuit.connect_pin(input_a, &"OUT", net_a)
	circuit.connect_pin(input_b, &"OUT", net_b)
	circuit.connect_pin(input_cin, &"OUT", net_cin)
	circuit.connect_pin(xor_chip, &"14", rails["VCC"])
	circuit.connect_pin(xor_chip, &"7", rails["GND"])
	circuit.connect_pin(xor_chip, &"12", net_a)
	circuit.connect_pin(xor_chip, &"13", net_b)
	circuit.connect_pin(xor_chip, &"11", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"9", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"10", net_cin)
	circuit.connect_pin(xor_chip, &"8", net_sum)
	circuit.connect_pin(and_chip, &"14", rails["VCC"])
	circuit.connect_pin(and_chip, &"7", rails["GND"])
	circuit.connect_pin(and_chip, &"1", net_a)
	circuit.connect_pin(and_chip, &"2", net_b)
	circuit.connect_pin(and_chip, &"3", net_a_and_b)
	circuit.connect_pin(and_chip, &"12", net_a_xor_b)
	circuit.connect_pin(and_chip, &"13", net_cin)
	circuit.connect_pin(and_chip, &"11", net_xor_and_cin)
	circuit.connect_pin(or_chip, &"14", rails["VCC"])
	circuit.connect_pin(or_chip, &"7", rails["GND"])
	circuit.connect_pin(or_chip, &"1", net_a_and_b)
	circuit.connect_pin(or_chip, &"2", net_xor_and_cin)
	circuit.connect_pin(or_chip, &"3", net_cout)

	_assert_true(circuit.settle(), "full adder IC circuit settled")
	return {
		"sum": circuit.nets[net_sum].value,
		"cout": circuit.nets[net_cout].value,
	}


func _assert_equal(actual: int, expected: int, message: String) -> void:
	if actual == expected:
		return

	_failures.append(
		"%s: expected %s, got %s" % [
			message,
			SignalValue.label(expected),
			SignalValue.label(actual),
		]
	)


func _assert_true(actual: bool, message: String) -> void:
	if actual:
		return
	_failures.append("%s: expected true, got false" % message)


func _net_has_bus(circuit, net_id: int, bus_id: String) -> bool:
	for connection: Dictionary in circuit.nets[net_id].connections:
		if connection.get("bus", "") == bus_id:
			return true
	return false


func _assert_false(actual: bool, message: String) -> void:
	if not actual:
		return
	_failures.append("%s: expected false, got true" % message)


func _bit_label(value: bool) -> String:
	return "1" if value else "0"
