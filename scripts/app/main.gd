extends Control

const BuiltinChipsScript = preload("res://scripts/sim/builtin_chips.gd")
const CircuitScript = preload("res://scripts/sim/circuit.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")
const WorkbenchViewScript = preload("res://scripts/ui/workbench_view.gd")

const TOOL_SELECT := &"select"
const TOOL_WIRE := &"wire"
const TOOL_PLACE := &"place"
const TOOL_BUTTONS := [
	{"id": TOOL_SELECT, "label": "P", "tooltip": "Pointer"},
	{"id": TOOL_WIRE, "label": "W", "tooltip": "Wire"},
]
const PART_BUTTONS := [
	{"id": &"toggle", "label": "SW", "tooltip": "Pushbutton"},
	{"id": &"led", "label": "LED", "tooltip": "LED"},
	{"id": &"ic_7486", "label": "86", "tooltip": "74LS86 XOR"},
	{"id": &"ic_7408", "label": "08", "tooltip": "74LS08 AND"},
	{"id": &"ic_7432", "label": "32", "tooltip": "74LS32 OR"},
	{"id": &"nand", "label": "00", "tooltip": "7400 NAND"},
	{"id": &"not", "label": "04", "tooltip": "7404 NOT"},
	{"id": &"resistor_220", "label": "220", "tooltip": "220 ohm resistor"},
	{"id": &"resistor_2k2", "label": "2K", "tooltip": "2.2K resistor"},
]

var _library: Dictionary = {}
var _circuit
var _workbench
var _status_label: Label
var _case_label: Label
var _result_label: Label
var _net_pills: Array[Label] = []
var _truth_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {}
var _part_buttons: Dictionary = {}
var _active_tool: StringName = TOOL_SELECT
var _active_part_id: StringName = &""
var _watched_nets: Array[String] = ["A", "B", "Cin", "SUM", "Cout"]
var _case_index := 0
var _verified_rows: Dictionary = {}
var _truth_rows: Array[Dictionary] = [
	{"a": false, "b": false, "cin": false, "sum": false, "cout": false},
	{"a": false, "b": false, "cin": true, "sum": true, "cout": false},
	{"a": false, "b": true, "cin": false, "sum": true, "cout": false},
	{"a": false, "b": true, "cin": true, "sum": false, "cout": true},
	{"a": true, "b": false, "cin": false, "sum": true, "cout": false},
	{"a": true, "b": false, "cin": true, "sum": false, "cout": true},
	{"a": true, "b": true, "cin": false, "sum": false, "cout": true},
	{"a": true, "b": true, "cin": true, "sum": true, "cout": true},
]


func _ready() -> void:
	_library = BuiltinChipsScript.create_standard_library()
	_build_ui()
	_circuit = _create_full_adder_circuit()
	_workbench.set_library(_library)
	_workbench.set_circuit(_circuit)
	_select_tool(TOOL_SELECT)
	_circuit.changed.connect(_update_status)
	_circuit.settle()
	_update_status()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.92, 0.89, 0.78), Color(0.54, 0.49, 0.36), 0, 0))
	root.add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_top", 10)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 44.0)
	top_bar.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_bar)

	var title := Label.new()
	title.text = "FULL ADDER LAB"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.12, 0.11, 0.08))
	top_bar.add_child(title)

	var pill_box := HBoxContainer.new()
	pill_box.add_theme_constant_override("separation", 7)
	top_bar.add_child(pill_box)
	_net_pills.clear()
	for name: String in _watched_nets:
		var pill := Label.new()
		pill.text = "%s=?" % name
		pill.custom_minimum_size = Vector2(54.0, 30.0)
		pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill.add_theme_font_size_override("font_size", 13)
		pill.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86))
		pill.add_theme_stylebox_override("normal", _make_style_box(Color(0.15, 0.15, 0.13), Color(0.46, 0.42, 0.32), 1, 6))
		pill_box.add_child(pill)
		_net_pills.append(pill)

	top_bar.add_child(_make_toolbar_button("Settle", Callable(self, "_on_settle_pressed")))
	top_bar.add_child(_make_toolbar_button("Reset", Callable(self, "_on_reset_pressed")))
	top_bar.add_child(_make_toolbar_button("Center", Callable(self, "_on_center_pressed")))

	var lab_body := HBoxContainer.new()
	lab_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lab_body.add_theme_constant_override("separation", 0)
	root.add_child(lab_body)

	lab_body.add_child(_build_toolbox())

	_workbench = WorkbenchViewScript.new()
	_workbench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workbench.circuit_interacted.connect(_update_status)
	lab_body.add_child(_workbench)

	lab_body.add_child(_build_lab_panel())

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.18, 0.17, 0.14), Color(0.07, 0.06, 0.05), 0, 0))
	root.add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 16)
	status_margin.add_theme_constant_override("margin_top", 8)
	status_margin.add_theme_constant_override("margin_right", 16)
	status_margin.add_theme_constant_override("margin_bottom", 8)
	status_panel.add_child(status_margin)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(0.0, 24.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.87, 0.84, 0.74))
	status_margin.add_child(_status_label)


func _build_toolbox() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(104.0, 0.0)
	panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.16, 0.16, 0.14), Color(0.07, 0.06, 0.05), 0, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	stack.add_child(_make_toolbox_header("TOOLS"))
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	tool_grid.add_theme_constant_override("h_separation", 6)
	tool_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(tool_grid)

	_tool_buttons.clear()
	for tool: Dictionary in TOOL_BUTTONS:
		var button := _make_toolbox_button(tool["label"], tool["tooltip"])
		button.pressed.connect(_on_tool_button_pressed.bind(tool["id"]))
		tool_grid.add_child(button)
		_tool_buttons[tool["id"]] = button

	stack.add_child(_make_toolbox_header("PARTS"))
	var part_grid := GridContainer.new()
	part_grid.columns = 2
	part_grid.add_theme_constant_override("h_separation", 6)
	part_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(part_grid)

	_part_buttons.clear()
	for part: Dictionary in PART_BUTTONS:
		if not _library.has(part["id"]):
			continue
		var button := _make_toolbox_button(part["label"], part["tooltip"])
		button.pressed.connect(_on_part_button_pressed.bind(part["id"]))
		part_grid.add_child(button)
		_part_buttons[part["id"]] = button

	return panel


func _make_toolbox_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.61))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_toolbox_button(label: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(40.0, 38.0)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.92, 0.90, 0.80))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.09, 0.06))
	button.add_theme_stylebox_override("normal", _make_style_box(Color(0.23, 0.23, 0.20), Color(0.40, 0.38, 0.31), 1, 4))
	button.add_theme_stylebox_override("hover", _make_style_box(Color(0.30, 0.30, 0.25), Color(0.78, 0.65, 0.31), 1, 4))
	button.add_theme_stylebox_override("pressed", _make_style_box(Color(0.94, 0.74, 0.24), Color(0.98, 0.88, 0.48), 1, 4))
	return button


func _build_lab_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(286.0, 0.0)
	panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.21, 0.20, 0.16), Color(0.07, 0.06, 0.05), 0, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "FULL ADDER"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.80))
	stack.add_child(title)

	_case_label = Label.new()
	_case_label.text = "CASE 1/8"
	_case_label.add_theme_font_size_override("font_size", 13)
	_case_label.add_theme_color_override("font_color", Color(0.70, 0.68, 0.58))
	stack.add_child(_case_label)

	_result_label = Label.new()
	_result_label.custom_minimum_size = Vector2(0.0, 42.0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
	_result_label.add_theme_stylebox_override("normal", _make_style_box(Color(0.10, 0.10, 0.08), Color(0.47, 0.43, 0.32), 1, 6))
	stack.add_child(_result_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	stack.add_child(button_row)
	button_row.add_child(_make_panel_button("Next Case", Callable(self, "_on_next_case_pressed")))
	button_row.add_child(_make_panel_button("Run Table", Callable(self, "_on_run_table_pressed")))

	var header := Label.new()
	header.text = "A  B  Cin   SUM  Cout"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.70, 0.68, 0.58))
	stack.add_child(header)

	_truth_buttons.clear()
	for index: int in range(_truth_rows.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.focus_mode = Control.FOCUS_NONE
		button.text = _truth_row_text(index)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color(0.92, 0.90, 0.80))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.86))
		button.add_theme_stylebox_override("normal", _make_style_box(Color(0.15, 0.145, 0.12), Color(0.36, 0.34, 0.27), 1, 5))
		button.add_theme_stylebox_override("hover", _make_style_box(Color(0.22, 0.21, 0.17), Color(0.70, 0.58, 0.29), 1, 5))
		button.add_theme_stylebox_override("pressed", _make_style_box(Color(0.10, 0.10, 0.08), Color(0.86, 0.68, 0.23), 1, 5))
		button.pressed.connect(_on_truth_row_pressed.bind(index))
		stack.add_child(button)
		_truth_buttons.append(button)

	return panel


func _create_full_adder_circuit():
	var library: Dictionary = _library if not _library.is_empty() else BuiltinChipsScript.create_standard_library()
	var circuit := CircuitScript.new()

	var input_cin = circuit.add_chip(library[&"toggle"], Vector2i(-25, -6), "Cin")
	var input_a = circuit.add_chip(library[&"toggle"], Vector2i(-21, -6), "A")
	var input_b = circuit.add_chip(library[&"toggle"], Vector2i(-17, -6), "B")
	var xor_chip = circuit.add_chip(library[&"ic_7486"], Vector2i(-10, -2), "7486")
	var and_chip = circuit.add_chip(library[&"ic_7408"], Vector2i(0, -2), "7408")
	var or_chip = circuit.add_chip(library[&"ic_7432"], Vector2i(10, -2), "7432")
	var sum_led = circuit.add_chip(library[&"led"], Vector2i(22, 2), "SUM")
	var carry_led = circuit.add_chip(library[&"led"], Vector2i(22, -6), "Cout")
	var pull_cin = circuit.add_chip(library[&"resistor_2k2"], Vector2i(-25, 5), "R1")
	var pull_a = circuit.add_chip(library[&"resistor_2k2"], Vector2i(-21, 5), "R2")
	var pull_b = circuit.add_chip(library[&"resistor_2k2"], Vector2i(-17, 5), "R3")
	var sum_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i(17, 3), "R4")
	var carry_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i(17, -5), "R5")

	input_a.state["on"] = false
	input_b.state["on"] = false
	input_cin.state["on"] = false

	var net_vcc = circuit.add_net("VCC")
	var net_gnd = circuit.add_net("GND")
	var net_a = circuit.add_net("A")
	var net_b = circuit.add_net("B")
	var net_cin = circuit.add_net("Cin")
	var net_a_xor_b = circuit.add_net("A xor B")
	var net_sum = circuit.add_net("SUM")
	var net_a_and_b = circuit.add_net("A and B")
	var net_xor_and_cin = circuit.add_net("(A xor B) and Cin")
	var net_cout = circuit.add_net("Cout")

	circuit.connect_pin(input_a, &"OUT", net_a)
	circuit.connect_pin(input_b, &"OUT", net_b)
	circuit.connect_pin(input_cin, &"OUT", net_cin)
	circuit.connect_pin(pull_a, &"A", net_a)
	circuit.connect_pin(pull_a, &"B", net_gnd)
	circuit.connect_pin(pull_b, &"A", net_b)
	circuit.connect_pin(pull_b, &"B", net_gnd)
	circuit.connect_pin(pull_cin, &"A", net_cin)
	circuit.connect_pin(pull_cin, &"B", net_gnd)

	circuit.connect_pin(xor_chip, &"14", net_vcc)
	circuit.connect_pin(xor_chip, &"7", net_gnd)
	circuit.connect_pin(xor_chip, &"12", net_a)
	circuit.connect_pin(xor_chip, &"13", net_b)
	circuit.connect_pin(xor_chip, &"11", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"9", net_a_xor_b)
	circuit.connect_pin(xor_chip, &"10", net_cin)
	circuit.connect_pin(xor_chip, &"8", net_sum)

	circuit.connect_pin(and_chip, &"14", net_vcc)
	circuit.connect_pin(and_chip, &"7", net_gnd)
	circuit.connect_pin(and_chip, &"1", net_a)
	circuit.connect_pin(and_chip, &"2", net_b)
	circuit.connect_pin(and_chip, &"3", net_a_and_b)
	circuit.connect_pin(and_chip, &"12", net_a_xor_b)
	circuit.connect_pin(and_chip, &"13", net_cin)
	circuit.connect_pin(and_chip, &"11", net_xor_and_cin)

	circuit.connect_pin(or_chip, &"14", net_vcc)
	circuit.connect_pin(or_chip, &"7", net_gnd)
	circuit.connect_pin(or_chip, &"1", net_a_and_b)
	circuit.connect_pin(or_chip, &"2", net_xor_and_cin)
	circuit.connect_pin(or_chip, &"3", net_cout)

	circuit.connect_pin(sum_resistor, &"A", net_sum)
	circuit.connect_pin(sum_resistor, &"B", net_gnd)
	circuit.connect_pin(sum_led, &"IN", net_sum)
	circuit.connect_pin(sum_led, &"GND", net_gnd)
	circuit.connect_pin(carry_resistor, &"A", net_cout)
	circuit.connect_pin(carry_resistor, &"B", net_gnd)
	circuit.connect_pin(carry_led, &"IN", net_cout)
	circuit.connect_pin(carry_led, &"GND", net_gnd)

	return circuit


func _on_tool_button_pressed(tool_id: StringName) -> void:
	_select_tool(tool_id)


func _on_part_button_pressed(part_id: StringName) -> void:
	_select_tool(TOOL_PLACE, part_id)


func _select_tool(tool_id: StringName, part_id: StringName = &"") -> void:
	_active_tool = tool_id
	_active_part_id = part_id
	if _workbench:
		_workbench.set_active_tool(_active_tool, _active_part_id)
	_update_tool_button_states()
	_update_status()


func _update_tool_button_states() -> void:
	for tool_id in _tool_buttons.keys():
		var button: Button = _tool_buttons[tool_id]
		button.set_pressed_no_signal(_active_tool == tool_id and _active_part_id == &"")

	for part_id in _part_buttons.keys():
		var button: Button = _part_buttons[part_id]
		button.set_pressed_no_signal(_active_tool == TOOL_PLACE and _active_part_id == part_id)


func _on_settle_pressed() -> void:
	_circuit.settle()
	_update_status()


func _on_reset_pressed() -> void:
	if _circuit and _circuit.changed.is_connected(_update_status):
		_circuit.changed.disconnect(_update_status)

	_circuit = _create_full_adder_circuit()
	_workbench.set_circuit(_circuit)
	_circuit.changed.connect(_update_status)
	_verified_rows.clear()
	_apply_truth_row(_case_index)
	_circuit.settle()
	_update_status()


func _on_center_pressed() -> void:
	_workbench.center_view()


func _on_next_case_pressed() -> void:
	_case_index = (_case_index + 1) % _truth_rows.size()
	_apply_truth_row(_case_index)
	_update_status()


func _on_run_table_pressed() -> void:
	var original_index := _case_index
	for index: int in range(_truth_rows.size()):
		_apply_truth_row(index)
		_verified_rows[index] = _current_row_matches(index)

	_case_index = original_index
	_apply_truth_row(_case_index)
	_update_status()


func _on_truth_row_pressed(row_index: int) -> void:
	_case_index = row_index
	_apply_truth_row(_case_index)
	_update_status()


func _update_status() -> void:
	if not _status_label or not _circuit:
		return

	var parts: Array[String] = []
	for index in _watched_nets.size():
		var net = _net_by_label(_watched_nets[index])
		if not net:
			continue
		var value_label := SignalValue.label(net.value)
		parts.append("%s=%s" % [net.label, value_label])
		if index < _net_pills.size():
			_net_pills[index].text = "%s=%s" % [net.label, value_label]
			_net_pills[index].add_theme_stylebox_override("normal", _make_style_box(Color(0.12, 0.12, 0.10), SignalValue.color(net.value), 2, 6))

	var current_row: Dictionary = _truth_rows[_case_index]
	var expected := "expected SUM=%s Cout=%s" % [_bit_label(current_row["sum"]), _bit_label(current_row["cout"])]
	var result_text := "MATCH" if _current_row_matches(_case_index) else "CHECK"
	_status_label.text = "Tool %s  Case %d/%d  %s  %s" % [
		_active_tool_label(),
		_case_index + 1,
		_truth_rows.size(),
		expected,
		"  ".join(parts),
	]

	if _case_label:
		_case_label.text = "CASE %d/%d" % [_case_index + 1, _truth_rows.size()]
	if _result_label:
		_result_label.text = result_text
		var result_color := Color(0.15, 0.42, 0.19) if result_text == "MATCH" else Color(0.38, 0.27, 0.10)
		var result_border := Color(0.36, 0.76, 0.30) if result_text == "MATCH" else Color(0.92, 0.70, 0.23)
		_result_label.add_theme_stylebox_override("normal", _make_style_box(result_color, result_border, 1, 6))
	_update_truth_table_styles()


func _active_tool_label() -> String:
	if _active_tool == TOOL_PLACE and _library.has(_active_part_id):
		return _library[_active_part_id].display_name
	if _active_tool == TOOL_WIRE:
		return "Wire"
	return "Pointer"


func _net_by_label(net_label: String):
	for net in _circuit.nets:
		if net.label == net_label:
			return net
	return null


func _apply_truth_row(row_index: int) -> void:
	var row: Dictionary = _truth_rows[row_index]
	_set_input("A", row["a"])
	_set_input("B", row["b"])
	_set_input("Cin", row["cin"])
	_circuit.settle()


func _set_input(label: String, value: bool) -> void:
	for chip in _circuit.chips:
		if chip.definition.id == &"toggle" and chip.label == label:
			chip.state["on"] = value
			return


func _current_row_matches(row_index: int) -> bool:
	var row: Dictionary = _truth_rows[row_index]
	var sum_net = _net_by_label("SUM")
	var cout_net = _net_by_label("Cout")
	if not sum_net or not cout_net:
		return false
	return sum_net.value == _signal_for_bit(row["sum"]) and cout_net.value == _signal_for_bit(row["cout"])


func _signal_for_bit(value: bool) -> int:
	return SignalValue.State.HIGH if value else SignalValue.State.LOW


func _truth_row_text(row_index: int) -> String:
	var row: Dictionary = _truth_rows[row_index]
	return "%d  %d   %d       %d     %d" % [
		int(row["a"]),
		int(row["b"]),
		int(row["cin"]),
		int(row["sum"]),
		int(row["cout"]),
	]


func _update_truth_table_styles() -> void:
	for index: int in range(_truth_buttons.size()):
		var button := _truth_buttons[index]
		var fill := Color(0.15, 0.145, 0.12)
		var border := Color(0.36, 0.34, 0.27)
		var font_color := Color(0.92, 0.90, 0.80)

		if index == _case_index:
			fill = Color(0.09, 0.18, 0.29)
			border = Color(0.14, 0.46, 0.88)
		elif _verified_rows.has(index):
			fill = Color(0.10, 0.24, 0.12) if _verified_rows[index] else Color(0.34, 0.12, 0.10)
			border = Color(0.30, 0.66, 0.26) if _verified_rows[index] else Color(0.85, 0.24, 0.18)

		button.text = _truth_row_text(index)
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_stylebox_override("normal", _make_style_box(fill, border, 1, 5))


func _make_toolbar_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(86.0, 34.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.84))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.88))
	button.add_theme_stylebox_override("normal", _make_style_box(Color(0.17, 0.18, 0.15), Color(0.47, 0.43, 0.32), 1, 6))
	button.add_theme_stylebox_override("hover", _make_style_box(Color(0.24, 0.25, 0.20), Color(0.78, 0.65, 0.31), 1, 6))
	button.add_theme_stylebox_override("pressed", _make_style_box(Color(0.09, 0.10, 0.08), Color(0.92, 0.73, 0.27), 1, 6))
	button.pressed.connect(callback)
	return button


func _make_panel_button(label: String, callback: Callable) -> Button:
	var button := _make_toolbar_button(label, callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 34.0)
	return button


func _make_style_box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


func _bit_label(value: bool) -> String:
	return "1" if value else "0"
