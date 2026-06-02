extends SceneTree

# Exercises the prebuilt levels in scripts/app/main.gd through the explicit
# jumper model: every pin and wire end must own a unique hole, and each level
# must still settle to its specified truth table.

const MainScript = preload("res://scripts/app/main.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")

var _failures: Array[String] = []


func _init() -> void:
	var app = MainScript.new()

	_test_unique_holes(app, "nand", app._create_nand_starter_circuit())
	_test_unique_holes(app, "half_adder", app._create_half_adder_circuit())
	_test_unique_holes(app, "full_adder", app._create_full_adder_circuit())

	_test_switch_inputs(app, "nand", app._create_nand_starter_circuit(), ["A", "B"])
	_test_switch_inputs(app, "half_adder", app._create_half_adder_circuit(), ["A", "B"])
	_test_switch_inputs(app, "full_adder", app._create_full_adder_circuit(), ["A", "B", "Cin"])

	_test_truth_table(app, "nand", app._create_nand_starter_circuit(), ["A", "B"], {
		"Y": [true, true, true, false],
	})
	_test_truth_table(app, "half_adder", app._create_half_adder_circuit(), ["A", "B"], {
		"SUM": [false, true, true, false],
		"CARRY": [false, false, false, true],
	})
	_test_truth_table(app, "full_adder", app._create_full_adder_circuit(), ["A", "B", "Cin"], {
		"SUM": [false, true, true, false, true, false, false, true],
		"Cout": [false, false, false, true, false, true, true, true],
	})

	app.free()

	if _failures.is_empty():
		print("level_tests: all tests passed")
		quit(0)
		return

	for failure: String in _failures:
		printerr(failure)
	printerr("level_tests: %d failure(s)" % _failures.size())
	quit(1)


# Confirms no two pins or wire ends share a hole, and that every wire ends in a
# distinct hole from where it starts.
func _test_unique_holes(app, level: String, circuit) -> void:
	var seen: Dictionary = {}

	for chip in circuit.chips:
		if chip.state.has("pin_holes"):
			for pin_key in chip.state["pin_holes"].keys():
				_claim_hole(seen, circuit.hole_key(chip.state["pin_holes"][pin_key]), "%s pin %s.%s" % [level, chip.label, pin_key])
		elif chip.state.has("dip_origin_column"):
			var origin: int = chip.state["dip_origin_column"]
			for pin: Dictionary in chip.definition.pins:
				var hole: Dictionary = app._dip_pin_hole(origin, int(str(pin.get("name"))))
				if not hole.is_empty():
					_claim_hole(seen, circuit.hole_key(hole), "%s DIP %s pin %s" % [level, chip.label, pin.get("name")])

	for wire: Dictionary in circuit.wires:
		var start_key: String = circuit.hole_key(wire["start"])
		var end_key: String = circuit.hole_key(wire["end"])
		_assert_true(start_key != end_key, "%s wire spans two distinct holes" % level)
		_claim_hole(seen, start_key, "%s wire start" % level)
		_claim_hole(seen, end_key, "%s wire end" % level)


func _claim_hole(seen: Dictionary, key: String, who: String) -> void:
	_assert_true(not key.is_empty(), "%s addresses a real hole" % who)
	_assert_true(not seen.has(key), "hole %s claimed once (wanted by %s, held by %s)" % [key, who, seen.get(key, "?")])
	seen[key] = who


func _test_truth_table(app, level: String, circuit, inputs: Array, outputs: Dictionary) -> void:
	var row_count := int(pow(2, inputs.size()))
	for row: int in range(row_count):
		for index: int in range(inputs.size()):
			var bit := (row >> (inputs.size() - 1 - index)) & 1
			_set_input(circuit, inputs[index], bit == 1)
		circuit.settle()

		for output_label: String in outputs.keys():
			var expected: bool = outputs[output_label][row]
			var net = _net_by_label(circuit, output_label)
			_assert_true(net != null, "%s exposes net %s" % [level, output_label])
			if net == null:
				continue
			var want := SignalValue.State.HIGH if expected else SignalValue.State.LOW
			_assert_equal(net.value, want, "%s row %d %s" % [level, row, output_label])


# Confirms inputs are real switch + pull-down circuits: a released switch leaves
# its net pulled LOW (not floating Z), and pressing it ties the net to +5V.
func _test_switch_inputs(app, level: String, circuit, inputs: Array) -> void:
	var switches := 0
	var pulldowns := 0
	for chip in circuit.chips:
		if chip.definition.id == &"switch":
			switches += 1
		elif chip.definition.id in [&"resistor_2k2", &"resistor_220"]:
			pulldowns += 1
	_assert_true(switches == inputs.size(), "%s has one switch per input" % level)
	_assert_true(pulldowns >= inputs.size(), "%s has a pull-down resistor per input" % level)

	for input_label: String in inputs:
		_set_input(circuit, input_label, false)
	circuit.settle()
	for input_label: String in inputs:
		var net = _net_by_label(circuit, input_label)
		_assert_true(net != null, "%s exposes input net %s" % [level, input_label])
		if net != null:
			_assert_equal(net.value, SignalValue.State.LOW, "%s input %s held low by pull-down when released" % [level, input_label])

	for input_label: String in inputs:
		_set_input(circuit, input_label, true)
		circuit.settle()
		var net = _net_by_label(circuit, input_label)
		if net != null:
			_assert_equal(net.value, SignalValue.State.HIGH, "%s input %s driven high when pressed" % [level, input_label])
		_set_input(circuit, input_label, false)


func _set_input(circuit, label: String, value: bool) -> void:
	for chip in circuit.chips:
		if chip.definition.id in [&"switch", &"toggle"] and chip.label == label:
			chip.state["on"] = value
			return


func _net_by_label(circuit, label: String):
	for net in circuit.nets:
		if net.label == label:
			return net
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("FAIL: %s" % message)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("FAIL: %s (expected %s, got %s)" % [message, expected, actual])
