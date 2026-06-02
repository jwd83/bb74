extends Control

const BuiltinChipsScript = preload("res://scripts/sim/builtin_chips.gd")
const CircuitScript = preload("res://scripts/sim/circuit.gd")
const SignalValue = preload("res://scripts/sim/signal_value.gd")
const WorkbenchViewScript = preload("res://scripts/ui/workbench_view.gd")

const TOOL_SELECT := &"select"
const TOOL_WIRE := &"wire"
const TOOL_PLACE := &"place"
const LEVEL_NAND := &"nand"
const LEVEL_HALF_ADDER := &"half_adder"
const LEVEL_FULL_ADDER := &"full_adder"
const LEVEL_SANDBOX := &"sandbox"
const DEFAULT_LEVEL_ID := LEVEL_NAND
const TOOL_BUTTONS := [
	{"id": TOOL_SELECT, "label": "P", "tooltip": "Pointer"},
	{"id": TOOL_WIRE, "label": "W", "tooltip": "Wire"},
]
const LEVEL_OPTIONS := [
	{"id": LEVEL_NAND, "label": "NAND"},
	{"id": LEVEL_HALF_ADDER, "label": "Half Adder"},
	{"id": LEVEL_FULL_ADDER, "label": "Full Adder"},
	{"id": LEVEL_SANDBOX, "label": "Sandbox"},
]
const PART_BUTTONS := [
	{"id": &"power_5v", "label": "5V", "tooltip": "5V supply"},
	{"id": &"ground", "label": "GND", "tooltip": "Ground"},
	{"id": &"switch", "label": "SW", "tooltip": "Pushbutton (pull-down input)"},
	{"id": &"led", "label": "LED", "tooltip": "LED"},
	{"id": &"ic_7400", "label": "00", "tooltip": "74LS00 NAND"},
	{"id": &"ic_7404", "label": "04", "tooltip": "74LS04 NOT"},
	{"id": &"ic_7486", "label": "86", "tooltip": "74LS86 XOR"},
	{"id": &"ic_7408", "label": "08", "tooltip": "74LS08 AND"},
	{"id": &"ic_7432", "label": "32", "tooltip": "74LS32 OR"},
	{"id": &"resistor_220", "label": "220", "tooltip": "220 ohm resistor"},
	{"id": &"resistor_2k2", "label": "2K", "tooltip": "2.2K resistor"},
]

var _library: Dictionary = {}
var _circuit
var _workbench
var _title_label: Label
var _level_picker: OptionButton
var _status_label: Label
var _pill_box: HBoxContainer
var _lab_title_label: Label
var _case_label: Label
var _result_label: Label
var _truth_header_label: Label
var _truth_button_box: VBoxContainer
var _next_case_button: Button
var _run_table_button: Button
var _net_pills: Array[Label] = []
var _truth_buttons: Array[Button] = []
var _tool_buttons: Dictionary = {}
var _part_buttons: Dictionary = {}
var _active_tool: StringName = TOOL_SELECT
var _active_part_id: StringName = &""
var _current_level_id: StringName = DEFAULT_LEVEL_ID
var _level_title := ""
var _truth_header := ""
var _input_labels: Array[String] = []
var _output_labels: Array[String] = []
var _watched_nets: Array[String] = []
var _case_index := 0
var _verified_rows: Dictionary = {}
var _truth_rows: Array[Dictionary] = []


func _ready() -> void:
	_library = BuiltinChipsScript.create_standard_library()
	_apply_level_metadata(DEFAULT_LEVEL_ID)
	_build_ui()
	_workbench.set_library(_library)
	_select_tool(TOOL_SELECT)
	_load_level(DEFAULT_LEVEL_ID)


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

	_title_label = Label.new()
	_title_label.text = "BREADBOARD 74"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.12, 0.11, 0.08))
	top_bar.add_child(_title_label)

	_level_picker = OptionButton.new()
	_level_picker.custom_minimum_size = Vector2(166.0, 34.0)
	_level_picker.focus_mode = Control.FOCUS_NONE
	_level_picker.add_theme_font_size_override("font_size", 13)
	_level_picker.add_theme_color_override("font_color", Color(0.95, 0.93, 0.84))
	_level_picker.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	_level_picker.add_theme_stylebox_override("normal", _make_style_box(Color(0.17, 0.18, 0.15), Color(0.47, 0.43, 0.32), 1, 6))
	_level_picker.add_theme_stylebox_override("hover", _make_style_box(Color(0.24, 0.25, 0.20), Color(0.78, 0.65, 0.31), 1, 6))
	for option_index: int in range(LEVEL_OPTIONS.size()):
		var option: Dictionary = LEVEL_OPTIONS[option_index]
		_level_picker.add_item(option["label"])
		_level_picker.set_item_metadata(option_index, option["id"])
	_level_picker.item_selected.connect(_on_level_selected)
	top_bar.add_child(_level_picker)

	_pill_box = HBoxContainer.new()
	_pill_box.add_theme_constant_override("separation", 7)
	top_bar.add_child(_pill_box)
	_rebuild_net_pills()

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

	_lab_title_label = Label.new()
	_lab_title_label.text = _level_title
	_lab_title_label.add_theme_font_size_override("font_size", 18)
	_lab_title_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.80))
	stack.add_child(_lab_title_label)

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
	_next_case_button = _make_panel_button("Next Case", Callable(self, "_on_next_case_pressed"))
	_run_table_button = _make_panel_button("Run Table", Callable(self, "_on_run_table_pressed"))
	button_row.add_child(_next_case_button)
	button_row.add_child(_run_table_button)

	_truth_header_label = Label.new()
	_truth_header_label.text = _truth_header
	_truth_header_label.add_theme_font_size_override("font_size", 12)
	_truth_header_label.add_theme_color_override("font_color", Color(0.70, 0.68, 0.58))
	stack.add_child(_truth_header_label)

	_truth_button_box = VBoxContainer.new()
	_truth_button_box.add_theme_constant_override("separation", 6)
	stack.add_child(_truth_button_box)
	_rebuild_truth_buttons()
	_update_lab_panel_for_level()

	return panel


func _apply_level_metadata(level_id: StringName) -> void:
	var metadata := _level_metadata(level_id)
	_current_level_id = level_id
	_level_title = metadata["title"]
	_truth_header = metadata["truth_header"]
	_input_labels = _duplicate_string_array(metadata["input_labels"])
	_output_labels = _duplicate_string_array(metadata["output_labels"])
	_watched_nets = _duplicate_string_array(metadata["watched_nets"])
	_truth_rows = _duplicate_truth_rows(metadata["truth_rows"])
	_case_index = 0
	_verified_rows.clear()

	if _lab_title_label:
		_lab_title_label.text = _level_title
	if _truth_header_label:
		_truth_header_label.text = _truth_header
	if _level_picker:
		_select_level_picker_item(level_id)
	_rebuild_net_pills()
	_rebuild_truth_buttons()
	_update_lab_panel_for_level()


func _level_metadata(level_id: StringName) -> Dictionary:
	match level_id:
		LEVEL_HALF_ADDER:
			return {
				"title": "HALF ADDER",
				"truth_header": "A  B   SUM  CARRY",
				"input_labels": ["A", "B"],
				"output_labels": ["SUM", "CARRY"],
				"watched_nets": ["A", "B", "SUM", "CARRY"],
				"truth_rows": [
					{"A": false, "B": false, "SUM": false, "CARRY": false},
					{"A": false, "B": true, "SUM": true, "CARRY": false},
					{"A": true, "B": false, "SUM": true, "CARRY": false},
					{"A": true, "B": true, "SUM": false, "CARRY": true},
				],
			}
		LEVEL_FULL_ADDER:
			return {
				"title": "FULL ADDER",
				"truth_header": "A  B  Cin   SUM  Cout",
				"input_labels": ["A", "B", "Cin"],
				"output_labels": ["SUM", "Cout"],
				"watched_nets": ["A", "B", "Cin", "SUM", "Cout"],
				"truth_rows": [
					{"A": false, "B": false, "Cin": false, "SUM": false, "Cout": false},
					{"A": false, "B": false, "Cin": true, "SUM": true, "Cout": false},
					{"A": false, "B": true, "Cin": false, "SUM": true, "Cout": false},
					{"A": false, "B": true, "Cin": true, "SUM": false, "Cout": true},
					{"A": true, "B": false, "Cin": false, "SUM": true, "Cout": false},
					{"A": true, "B": false, "Cin": true, "SUM": false, "Cout": true},
					{"A": true, "B": true, "Cin": false, "SUM": false, "Cout": true},
					{"A": true, "B": true, "Cin": true, "SUM": true, "Cout": true},
				],
			}
		LEVEL_SANDBOX:
			return {
				"title": "SANDBOX",
				"truth_header": "",
				"input_labels": [],
				"output_labels": [],
				"watched_nets": [],
				"truth_rows": [],
			}
		_:
			return {
				"title": "NAND STARTER",
				"truth_header": "A  B   Y",
				"input_labels": ["A", "B"],
				"output_labels": ["Y"],
				"watched_nets": ["A", "B", "Y"],
				"truth_rows": [
					{"A": false, "B": false, "Y": true},
					{"A": false, "B": true, "Y": true},
					{"A": true, "B": false, "Y": true},
					{"A": true, "B": true, "Y": false},
				],
			}


func _duplicate_string_array(values: Array) -> Array[String]:
	var copied: Array[String] = []
	for value in values:
		copied.append(str(value))
	return copied


func _duplicate_truth_rows(values: Array) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for value: Dictionary in values:
		copied.append(value.duplicate())
	return copied


func _load_level(level_id: StringName) -> void:
	if _circuit and _circuit.changed.is_connected(_update_status):
		_circuit.changed.disconnect(_update_status)

	_apply_level_metadata(level_id)
	_circuit = _create_level_circuit(level_id)
	_workbench.set_circuit(_circuit)
	_circuit.changed.connect(_update_status)
	if _truth_rows.is_empty():
		_circuit.settle()
	else:
		_apply_truth_row(_case_index)
	_update_status()


func _create_level_circuit(level_id: StringName):
	match level_id:
		LEVEL_HALF_ADDER:
			return _create_half_adder_circuit()
		LEVEL_FULL_ADDER:
			return _create_full_adder_circuit()
		LEVEL_SANDBOX:
			return _create_sandbox_circuit()
		_:
			return _create_nand_starter_circuit()


const RAIL_HOLE_COUNT := 52
const RAIL_TOP_PLUS := "top:plus"
const RAIL_BOTTOM_MINUS := "bottom:minus"


func _active_library() -> Dictionary:
	return _library if not _library.is_empty() else BuiltinChipsScript.create_standard_library()


# Places the off-board 5V/GND supply terminals and binds them to the power rails.
func _add_power_rails(circuit, power_position: Vector2i, ground_position: Vector2i) -> Dictionary:
	var library: Dictionary = _active_library()
	var power = circuit.add_chip(library[&"power_5v"], power_position, "5V")
	var ground = circuit.add_chip(library[&"ground"], ground_position, "GND")
	var net_vcc: int = circuit.bus_net("rail:%s" % RAIL_TOP_PLUS, "VCC")
	var net_gnd: int = circuit.bus_net("rail:%s" % RAIL_BOTTOM_MINUS, "GND")

	circuit.connect_pin(power, &"OUT", net_vcc)
	circuit.connect_pin(ground, &"OUT", net_gnd)

	return {"VCC": net_vcc, "GND": net_gnd}


# Maps a DIP pin number to the single breadboard hole it sits in. Pins 1-7 line
# the bottom strip (row 5); pins 8-14 line the top strip (row 4), straddling the
# centre groove exactly as a real DIP package does.
func _dip_pin_hole(origin_column: int, pin_number: int) -> Dictionary:
	if pin_number >= 1 and pin_number <= 7:
		return {"column": origin_column + pin_number - 1, "row": 5}
	if pin_number >= 8 and pin_number <= 14:
		return {"column": origin_column + 14 - pin_number, "row": 4}
	return {}


# Inserts a DIP package: every pin claims its own hole and joins that column's
# strip net so neighbouring jumpers can pick it up.
func _place_dip(circuit, chip, origin_column: int) -> void:
	chip.state["dip_origin_column"] = origin_column
	for pin: Dictionary in chip.definition.pins:
		var pin_name: StringName = pin.get("name")
		var hole := _dip_pin_hole(origin_column, int(str(pin_name)))
		if hole.is_empty():
			continue
		circuit.occupy_hole(hole, {"chip": chip, "pin": pin_name})
		circuit.connect_pin(chip, pin_name, circuit.bus_net(circuit.hole_bus_id(hole)))


# Inserts a discrete component pin into one hole and joins its strip net.
func _place_pin(circuit, chip, pin_name: StringName, hole: Dictionary, net_label: String = "") -> int:
	if not chip.state.has("pin_holes"):
		chip.state["pin_holes"] = {}
	chip.state["pin_holes"][str(pin_name)] = {"column": int(hole["column"]), "row": int(hole["row"])}
	circuit.occupy_hole(hole, {"chip": chip, "pin": pin_name})
	var net_id: int = circuit.bus_net(circuit.hole_bus_id(hole), net_label)
	circuit.connect_pin(chip, pin_name, net_id)
	return net_id


# Returns the first unused hole in a terminal column-half, or {} if the strip is
# full. Reserving the next free row is how a signal fans out across the strip.
func _free_terminal_hole(circuit, column: int, half: String) -> Dictionary:
	var rows := [0, 1, 2, 3, 4] if half == "top" else [5, 6, 7, 8, 9]
	for row: int in rows:
		var hole := {"column": column, "row": row}
		if circuit.is_hole_free(hole):
			return hole
	push_error("No free hole in column %d %s strip." % [column, half])
	return {}


# Returns a free rail hole, preferring one nearest preferred_index so a rail
# jumper drops more or less straight down to the column it powers. Rail holes are
# spaced one-per-column, so the target column makes a good preference.
func _free_rail_hole(circuit, rail: String, preferred_index: int = 0) -> Dictionary:
	for offset: int in range(RAIL_HOLE_COUNT):
		for direction: int in ([0] if offset == 0 else [1, -1]):
			var index := preferred_index + offset * direction
			if index < 0 or index >= RAIL_HOLE_COUNT:
				continue
			var hole := {"rail": rail, "index": index}
			if circuit.is_hole_free(hole):
				return hole
	push_error("No free hole in rail %s." % rail)
	return {}


# Runs a jumper between two terminal strips, each end taking its own free hole.
func _wire_columns(circuit, from_column: int, from_half: String, to_column: int, to_half: String, net_label: String = "") -> int:
	var start_hole := _free_terminal_hole(circuit, from_column, from_half)
	var end_hole := _free_terminal_hole(circuit, to_column, to_half)
	if start_hole.is_empty() or end_hole.is_empty():
		return -1
	return circuit.add_wire(start_hole, end_hole, net_label)


# Runs a jumper from a power rail to a terminal strip.
func _wire_rail_to_column(circuit, rail: String, column: int, half: String, net_label: String = "") -> int:
	var start_hole := _free_rail_hole(circuit, rail, column)
	var end_hole := _free_terminal_hole(circuit, column, half)
	if start_hole.is_empty() or end_hole.is_empty():
		return -1
	return circuit.add_wire(start_hole, end_hole, net_label)


func _label_column_net(circuit, column: int, half: String, label: String) -> void:
	circuit.bus_net("terminal:%d:%s" % [column, half], label)


# Builds a resistor + LED indicator branch fed from a source column. The resistor
# bridges res_a_col -> res_b_col; the LED shares res_b_col's strip and grounds out
# through its own column to the negative rail.
func _place_led_branch(circuit, led, resistor, source_column: int, source_half: String, res_a_col: int, res_b_col: int, led_gnd_col: int, label: String) -> void:
	_place_pin(circuit, resistor, &"A", {"column": res_a_col, "row": 5})
	_place_pin(circuit, resistor, &"B", {"column": res_b_col, "row": 5})
	_place_pin(circuit, led, &"IN", _free_terminal_hole(circuit, res_b_col, "bottom"))
	_place_pin(circuit, led, &"GND", {"column": led_gnd_col, "row": 5})
	_wire_columns(circuit, source_column, source_half, res_a_col, "bottom", label)
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, led_gnd_col, "bottom", "GND")


# Builds a real pushbutton input: the switch straddles the centre groove with its
# top leg jumpered to the + rail and its bottom leg (the signal node) held LOW by a
# pull-down resistor to the - rail. Pressing the switch ties the node to +5V.
func _place_input_switch(circuit, switch, pulldown, sig_col: int, pd_col: int, label: String) -> void:
	switch.state["on"] = false
	_place_pin(circuit, switch, &"A", {"column": sig_col, "row": 4})         # top strip -> +rail
	_place_pin(circuit, switch, &"B", {"column": sig_col, "row": 5}, label)  # bottom strip = signal
	_place_pin(circuit, pulldown, &"A", {"column": sig_col, "row": 6})       # pull-down on the signal strip
	_place_pin(circuit, pulldown, &"B", {"column": pd_col, "row": 5})
	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, sig_col, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, pd_col, "bottom", "GND")


func _create_sandbox_circuit():
	var circuit := CircuitScript.new()
	return circuit


func _create_nand_starter_circuit():
	var library: Dictionary = _active_library()
	var circuit := CircuitScript.new()
	_add_power_rails(circuit, Vector2i(-24, -8), Vector2i(-24, 5))

	var input_a = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "B")
	var pulldown_a = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RA")
	var pulldown_b = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RB")
	var nand_chip = circuit.add_chip(library[&"ic_7400"], Vector2i(-4, -2), "7400")
	var output_led = circuit.add_chip(library[&"led"], Vector2i(10, -1), "Y")
	var output_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i.ZERO, "R1")

	# NAND gate A occupies pins 1 (col 10), 2 (col 11), 3 (col 12); power on 14/7.
	_place_dip(circuit, nand_chip, 10)
	_place_input_switch(circuit, input_a, pulldown_a, 2, 3, "A")
	_place_input_switch(circuit, input_b, pulldown_b, 5, 6, "B")
	_label_column_net(circuit, 12, "bottom", "Y")

	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 10, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 16, "bottom", "GND")
	_wire_columns(circuit, 2, "bottom", 10, "bottom", "A")
	_wire_columns(circuit, 5, "bottom", 11, "bottom", "B")
	_place_led_branch(circuit, output_led, output_resistor, 12, "bottom", 20, 23, 25, "Y")

	return circuit


func _create_half_adder_circuit():
	var library: Dictionary = _active_library()
	var circuit := CircuitScript.new()
	_add_power_rails(circuit, Vector2i(-26, -8), Vector2i(-26, 5))

	var input_a = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "B")
	var pulldown_a = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RA")
	var pulldown_b = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RB")
	var xor_chip = circuit.add_chip(library[&"ic_7486"], Vector2i(-5, -5), "7486")
	var and_chip = circuit.add_chip(library[&"ic_7408"], Vector2i(-5, 2), "7408")
	var sum_led = circuit.add_chip(library[&"led"], Vector2i(1, 2), "SUM")
	var sum_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i.ZERO, "R1")
	var carry_led = circuit.add_chip(library[&"led"], Vector2i(14, 2), "CARRY")
	var carry_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i.ZERO, "R2")

	_place_dip(circuit, xor_chip, 10)
	_place_dip(circuit, and_chip, 20)
	_place_input_switch(circuit, input_a, pulldown_a, 2, 3, "A")
	_place_input_switch(circuit, input_b, pulldown_b, 5, 6, "B")
	_label_column_net(circuit, 12, "bottom", "SUM")
	_label_column_net(circuit, 22, "bottom", "CARRY")

	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 10, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 16, "bottom", "GND")
	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 20, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 26, "bottom", "GND")

	# A and B each fan out to both gates from separate holes on their own strip.
	_wire_columns(circuit, 2, "bottom", 10, "bottom", "A")
	_wire_columns(circuit, 2, "bottom", 20, "bottom", "A")
	_wire_columns(circuit, 5, "bottom", 11, "bottom", "B")
	_wire_columns(circuit, 5, "bottom", 21, "bottom", "B")

	_place_led_branch(circuit, sum_led, sum_resistor, 12, "bottom", 30, 33, 35, "SUM")
	_place_led_branch(circuit, carry_led, carry_resistor, 22, "bottom", 40, 43, 45, "CARRY")

	return circuit


func _create_full_adder_circuit():
	var library: Dictionary = _active_library()
	var circuit := CircuitScript.new()
	_add_power_rails(circuit, Vector2i(-30, -8), Vector2i(-30, 5))

	var input_a = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "A")
	var input_b = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "B")
	var input_cin = circuit.add_chip(library[&"switch"], Vector2i.ZERO, "Cin")
	var pulldown_a = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RA")
	var pulldown_b = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RB")
	var pulldown_cin = circuit.add_chip(library[&"resistor_2k2"], Vector2i.ZERO, "RC")
	var xor_chip = circuit.add_chip(library[&"ic_7486"], Vector2i(-10, -2), "7486")
	var and_chip = circuit.add_chip(library[&"ic_7408"], Vector2i(0, -2), "7408")
	var or_chip = circuit.add_chip(library[&"ic_7432"], Vector2i(10, -2), "7432")
	var sum_led = circuit.add_chip(library[&"led"], Vector2i(2, 2), "SUM")
	var sum_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i.ZERO, "R1")
	var carry_led = circuit.add_chip(library[&"led"], Vector2i(20, 2), "Cout")
	var carry_resistor = circuit.add_chip(library[&"resistor_220"], Vector2i.ZERO, "R2")

	# XOR pins 1-7 -> cols 11-17, AND -> cols 22-28, OR -> cols 33-39.
	_place_dip(circuit, xor_chip, 11)
	_place_dip(circuit, and_chip, 22)
	_place_dip(circuit, or_chip, 33)
	_place_input_switch(circuit, input_a, pulldown_a, 1, 2, "A")
	_place_input_switch(circuit, input_b, pulldown_b, 4, 5, "B")
	_place_input_switch(circuit, input_cin, pulldown_cin, 7, 8, "Cin")
	_label_column_net(circuit, 13, "bottom", "A xor B")
	_label_column_net(circuit, 16, "bottom", "SUM")
	_label_column_net(circuit, 24, "bottom", "A and B")
	_label_column_net(circuit, 27, "bottom", "(A xor B) and Cin")
	_label_column_net(circuit, 35, "bottom", "Cout")

	# Power every chip from the rails.
	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 11, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 17, "bottom", "GND")
	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 22, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 28, "bottom", "GND")
	_wire_rail_to_column(circuit, RAIL_TOP_PLUS, 33, "top", "VCC")
	_wire_rail_to_column(circuit, RAIL_BOTTOM_MINUS, 39, "bottom", "GND")

	# Inputs fan out to the XOR and AND stages.
	_wire_columns(circuit, 1, "bottom", 11, "bottom", "A")
	_wire_columns(circuit, 1, "bottom", 22, "bottom", "A")
	_wire_columns(circuit, 4, "bottom", 12, "bottom", "B")
	_wire_columns(circuit, 4, "bottom", 23, "bottom", "B")
	_wire_columns(circuit, 7, "bottom", 15, "bottom", "Cin")
	_wire_columns(circuit, 7, "bottom", 26, "bottom", "Cin")

	# A xor B feeds the second XOR input and the AND's second input.
	_wire_columns(circuit, 13, "bottom", 14, "bottom", "A xor B")
	_wire_columns(circuit, 13, "bottom", 25, "bottom", "A xor B")

	# Carry path: (A and B) and ((A xor B) and Cin) into the OR gate.
	_wire_columns(circuit, 24, "bottom", 33, "bottom", "A and B")
	_wire_columns(circuit, 27, "bottom", 34, "bottom", "(A xor B) and Cin")

	_place_led_branch(circuit, sum_led, sum_resistor, 16, "bottom", 41, 44, 46, "SUM")
	_place_led_branch(circuit, carry_led, carry_resistor, 35, "bottom", 47, 49, 51, "Cout")

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


func _on_level_selected(item_index: int) -> void:
	var level_id: StringName = _level_picker.get_item_metadata(item_index)
	_load_level(level_id)


func _select_level_picker_item(level_id: StringName) -> void:
	for item_index: int in range(_level_picker.item_count):
		if _level_picker.get_item_metadata(item_index) == level_id:
			_level_picker.select(item_index)
			return


func _rebuild_net_pills() -> void:
	if not _pill_box:
		return

	for child in _pill_box.get_children():
		_pill_box.remove_child(child)
		child.queue_free()

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
		_pill_box.add_child(pill)
		_net_pills.append(pill)


func _rebuild_truth_buttons() -> void:
	if not _truth_button_box:
		return

	for child in _truth_button_box.get_children():
		_truth_button_box.remove_child(child)
		child.queue_free()

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
		_truth_button_box.add_child(button)
		_truth_buttons.append(button)


func _update_lab_panel_for_level() -> void:
	var has_truth := not _truth_rows.is_empty()
	if _truth_header_label:
		_truth_header_label.text = _truth_header
		_truth_header_label.visible = has_truth
	if _truth_button_box:
		_truth_button_box.visible = has_truth
	if _next_case_button:
		_next_case_button.visible = has_truth
	if _run_table_button:
		_run_table_button.visible = has_truth


func _on_settle_pressed() -> void:
	_circuit.settle()
	_update_status()


func _on_reset_pressed() -> void:
	_load_level(_current_level_id)


func _on_center_pressed() -> void:
	_workbench.center_view()


func _on_next_case_pressed() -> void:
	if _truth_rows.is_empty():
		return

	_case_index = (_case_index + 1) % _truth_rows.size()
	_apply_truth_row(_case_index)
	_update_status()


func _on_run_table_pressed() -> void:
	if _truth_rows.is_empty():
		return

	var original_index := _case_index
	for index: int in range(_truth_rows.size()):
		_apply_truth_row(index)
		_verified_rows[index] = _current_row_matches(index)

	_case_index = original_index
	_apply_truth_row(_case_index)
	_update_status()


func _on_truth_row_pressed(row_index: int) -> void:
	if row_index < 0 or row_index >= _truth_rows.size():
		return

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

	var expected := "free build"
	var case_text := _level_title
	var result_text := "READY"
	if not _truth_rows.is_empty():
		expected = _expected_text(_case_index)
		case_text = "Case %d/%d" % [_case_index + 1, _truth_rows.size()]
		result_text = "MATCH" if _current_row_matches(_case_index) else "CHECK"

	var watched_text := "  ".join(parts)
	_status_label.text = "Tool %s  %s  %s%s" % [
		_active_tool_label(),
		case_text,
		expected,
		"  %s" % watched_text if not watched_text.is_empty() else "",
	]

	if _case_label:
		_case_label.text = "CASE %d/%d" % [_case_index + 1, _truth_rows.size()] if not _truth_rows.is_empty() else "FREE BUILD"
	if _result_label:
		_result_label.text = result_text
		var result_color := Color(0.15, 0.42, 0.19) if result_text in ["MATCH", "READY"] else Color(0.38, 0.27, 0.10)
		var result_border := Color(0.36, 0.76, 0.30) if result_text in ["MATCH", "READY"] else Color(0.92, 0.70, 0.23)
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


func _expected_text(row_index: int) -> String:
	if row_index < 0 or row_index >= _truth_rows.size():
		return ""

	var row: Dictionary = _truth_rows[row_index]
	var expected_parts: Array[String] = []
	for output_label: String in _output_labels:
		expected_parts.append("%s=%s" % [output_label, _bit_label(row.get(output_label, false))])
	return "expected %s" % " ".join(expected_parts)


func _apply_truth_row(row_index: int) -> void:
	if row_index < 0 or row_index >= _truth_rows.size():
		return

	var row: Dictionary = _truth_rows[row_index]
	for input_label: String in _input_labels:
		_set_input(input_label, row.get(input_label, false))
	_circuit.settle()


func _set_input(label: String, value: bool) -> void:
	for chip in _circuit.chips:
		if chip.definition.id in [&"switch", &"toggle"] and chip.label == label:
			chip.state["on"] = value
			return


func _current_row_matches(row_index: int) -> bool:
	if row_index < 0 or row_index >= _truth_rows.size():
		return false

	var row: Dictionary = _truth_rows[row_index]
	for output_label: String in _output_labels:
		var output_net = _net_by_label(output_label)
		if not output_net:
			return false
		if output_net.value != _signal_for_bit(row.get(output_label, false)):
			return false
	return true


func _signal_for_bit(value: bool) -> int:
	return SignalValue.State.HIGH if value else SignalValue.State.LOW


func _truth_row_text(row_index: int) -> String:
	if row_index < 0 or row_index >= _truth_rows.size():
		return ""

	var row: Dictionary = _truth_rows[row_index]
	var parts: Array[String] = []
	for input_label: String in _input_labels:
		parts.append(_bit_label(row.get(input_label, false)))
	parts.append(" ")
	for output_label: String in _output_labels:
		parts.append(_bit_label(row.get(output_label, false)))
	return "  ".join(parts)


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
