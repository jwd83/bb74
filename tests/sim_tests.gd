extends SceneTree

const BuiltinChipsScript = preload("res://scripts/sim/builtin_chips.gd")
const CircuitScript = preload("res://scripts/sim/circuit.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_signal_resolution()
	_test_binary_gate_truth_tables()
	_test_not_truth_table()
	_test_conflicting_toggle_drivers()
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
		&"nand": [SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.LOW],
		&"and": [SignalValue.State.LOW, SignalValue.State.LOW, SignalValue.State.LOW, SignalValue.State.HIGH],
		&"or": [SignalValue.State.LOW, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.HIGH],
		&"xor": [SignalValue.State.LOW, SignalValue.State.HIGH, SignalValue.State.HIGH, SignalValue.State.LOW],
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
	_assert_equal(_simulate_unary_gate(&"not", false), SignalValue.State.HIGH, "not(0)")
	_assert_equal(_simulate_unary_gate(&"not", true), SignalValue.State.LOW, "not(1)")


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


func _simulate_unary_gate(chip_id: StringName, input_on: bool) -> int:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "Input")
	var gate = circuit.add_chip(library[chip_id], Vector2i.ONE, "Gate")
	var input_net: int = circuit.add_net("A")
	var output_net: int = circuit.add_net("Y")

	input.state["on"] = input_on
	circuit.connect_pin(input, &"OUT", input_net)
	circuit.connect_pin(gate, &"A", input_net)
	circuit.connect_pin(gate, &"Y", output_net)

	_assert_true(circuit.settle(), "%s settled" % chip_id)
	return circuit.nets[output_net].value


func _simulate_binary_gate(chip_id: StringName, input_a_on: bool, input_b_on: bool) -> int:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
	var input_a = circuit.add_chip(library[&"toggle"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"toggle"], Vector2i.ONE, "B")
	var gate = circuit.add_chip(library[chip_id], Vector2i(2, 0), "Gate")
	var net_a: int = circuit.add_net("A")
	var net_b: int = circuit.add_net("B")
	var net_y: int = circuit.add_net("Y")

	input_a.state["on"] = input_a_on
	input_b.state["on"] = input_b_on
	circuit.connect_pin(input_a, &"OUT", net_a)
	circuit.connect_pin(gate, &"A", net_a)
	circuit.connect_pin(input_b, &"OUT", net_b)
	circuit.connect_pin(gate, &"B", net_b)
	circuit.connect_pin(gate, &"Y", net_y)

	_assert_true(circuit.settle(), "%s settled" % chip_id)
	return circuit.nets[net_y].value


func _simulate_full_adder(input_a_on: bool, input_b_on: bool, input_cin_on: bool) -> Dictionary:
	var library: Dictionary = BuiltinChipsScript.create_standard_library()
	var circuit = CircuitScript.new()
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
	circuit.connect_pin(xor_chip, &"12", net_a)
	circuit.connect_pin(xor_chip, &"13", net_b)
	circuit.connect_pin(xor_chip, &"11", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"9", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"10", net_cin)
	circuit.connect_pin(xor_chip, &"8", net_sum)
	circuit.connect_pin(and_chip, &"1", net_a)
	circuit.connect_pin(and_chip, &"2", net_b)
	circuit.connect_pin(and_chip, &"3", net_a_and_b)
	circuit.connect_pin(and_chip, &"12", net_a_xor_b)
	circuit.connect_pin(and_chip, &"13", net_cin)
	circuit.connect_pin(and_chip, &"11", net_xor_and_cin)
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


func _bit_label(value: bool) -> String:
	return "1" if value else "0"
