class_name WorkbenchView
extends Control

const SignalValue = preload("res://scripts/sim/signal_value.gd")

signal circuit_interacted

const CHIP_SIZE := Vector2(124.0, 70.0)
const GRID_SPACING := 20.0
const BOARD_GRID_RECT := Rect2(Vector2(-30.0, -11.5), Vector2(60.0, 23.0))
const BREADBOARD_COLUMNS := 52
const RAIL_HOLE_COUNT := 52
const BREADBOARD_COLUMN_LEFT := 90.0
const BREADBOARD_HOLE_PITCH := 20.0
const BREADBOARD_TOP_PLUS_Y := 42.0
const BREADBOARD_TOP_MINUS_Y := 74.0
const BREADBOARD_TOP_TERMINAL_Y := 134.0
const BREADBOARD_BOTTOM_TERMINAL_Y := 254.0
const BREADBOARD_BOTTOM_PLUS_Y := 398.0
const BREADBOARD_BOTTOM_MINUS_Y := 430.0
const DIP_PIN_SPACING := 20.0
const DIP_VISUAL_SIZE := Vector2(160.0, 92.0)
const DEFAULT_PAN := Vector2(0.0, -72.0)
const TOOL_SELECT := &"select"
const TOOL_WIRE := &"wire"
const TOOL_PLACE := &"place"
const WIRE_COLORS := [
	Color(0.92, 0.09, 0.08),
	Color(0.04, 0.34, 0.86),
	Color(0.96, 0.76, 0.07),
	Color(0.06, 0.58, 0.20),
	Color(0.05, 0.05, 0.05),
	Color(0.88, 0.88, 0.84),
]

var circuit
var library: Dictionary = {}
var pan := DEFAULT_PAN
var zoom := 1.0
var active_tool: StringName = TOOL_SELECT
var selected_part_id: StringName = &""

var _is_panning := false
var _last_mouse_position := Vector2.ZERO
var _last_mouse_screen_position := Vector2.ZERO
var _hovered_net_id := -1
var _hovered_hole: Dictionary = {}
var _wire_start: Dictionary = {}
var _has_placement_ghost := false
var _ghost_grid_position := Vector2i.ZERO
var _next_wire_net_number := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_circuit(next_circuit) -> void:
	if circuit and circuit.changed.is_connected(queue_redraw):
		circuit.changed.disconnect(queue_redraw)

	circuit = next_circuit
	_hovered_net_id = -1
	_hovered_hole.clear()
	_wire_start.clear()
	if circuit:
		circuit.changed.connect(queue_redraw)
	queue_redraw()


func set_library(next_library: Dictionary) -> void:
	library = next_library
	queue_redraw()


func set_active_tool(tool_mode: StringName, part_id: StringName = &"") -> void:
	active_tool = tool_mode
	selected_part_id = part_id
	_wire_start.clear()
	_hovered_hole.clear()
	_has_placement_ghost = false
	_set_hovered_net(-1)
	queue_redraw()


func center_view() -> void:
	pan = DEFAULT_PAN
	zoom = 1.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_last_mouse_screen_position = event.position
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.08)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.08)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_panning = event.pressed
		_last_mouse_position = event.position
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_transient_tool_state()
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if active_tool == TOOL_PLACE:
			_place_selected_part(event.position)
			return
		if active_tool == TOOL_WIRE:
			_handle_wire_click(event.position)
			return

		var chip = _chip_at(event.position)
		if chip and chip.definition.id in [&"toggle", &"switch"]:
			chip.state["on"] = not chip.state.get("on", false)
			circuit.settle()
			circuit_interacted.emit()
			queue_redraw()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_last_mouse_screen_position = event.position
	if not _is_panning:
		_update_tool_hover(event.position)
		return

	pan += event.position - _last_mouse_position
	_last_mouse_position = event.position
	_set_hovered_net(-1)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hovered_net(-1)
		_hovered_hole.clear()
		_has_placement_ghost = false
		queue_redraw()


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_position)
	zoom = clampf(zoom * factor, 0.35, 2.75)
	var after := _screen_to_world(screen_position)
	pan += (after - before) * zoom
	queue_redraw()


func _update_tool_hover(screen_position: Vector2) -> void:
	match active_tool:
		TOOL_PLACE:
			var definition = _selected_part_definition()
			_has_placement_ghost = definition != null
			if definition:
				_ghost_grid_position = _snapped_grid_position_for_definition(screen_position, definition)
			_hovered_hole.clear()
			_set_hovered_net(-1)
			queue_redraw()
		TOOL_WIRE:
			_hovered_hole = _wire_hole_at(screen_position)
			_set_hovered_net(_hover_net_at(screen_position))
			queue_redraw()
		_:
			_hovered_hole.clear()
			_has_placement_ghost = false
			_set_hovered_net(_hover_net_at(screen_position))


func _place_selected_part(screen_position: Vector2) -> void:
	if not circuit:
		return

	var definition = _selected_part_definition()
	if not definition:
		return

	var chip = circuit.add_chip(
		definition,
		_snapped_grid_position_for_definition(screen_position, definition),
		_next_chip_label(definition)
	)
	_snap_new_chip_to_breadboard(chip, definition, screen_position)
	if definition.id == &"toggle":
		chip.state["on"] = false

	circuit.settle()
	circuit_interacted.emit()
	queue_redraw()


func _handle_wire_click(screen_position: Vector2) -> void:
	if not circuit:
		return

	var hole := _wire_hole_at(screen_position)
	if hole.is_empty():
		_wire_start.clear()
		queue_redraw()
		return

	if _wire_start.is_empty():
		_wire_start = hole
		queue_redraw()
		return

	if circuit.hole_key(_wire_start) == circuit.hole_key(hole):
		_wire_start.clear()
		queue_redraw()
		return

	var net_id: int = circuit.add_wire(_wire_start, hole, _next_wire_net_label())
	_wire_start.clear()
	if net_id >= 0:
		circuit.settle()
		circuit_interacted.emit()
	queue_redraw()


# Resolves the breadboard hole a wire-tool click should grab. Clicking a pin
# grabs a free hole on that pin's own strip (the pin's own hole stays occupied);
# clicking bare board grabs that exact hole if it is empty.
func _wire_hole_at(screen_position: Vector2) -> Dictionary:
	if not circuit:
		return {}

	var pin_hit := _pin_at(screen_position)
	if not pin_hit.is_empty():
		var pin_hole := _breadboard_hole_for_pin(pin_hit["chip"], pin_hit["pin"])
		if not pin_hole.is_empty():
			var half := "top" if int(pin_hole["row"]) < 5 else "bottom"
			var free := _free_column_hole(int(pin_hole["column"]), half)
			if not free.is_empty():
				return free

	var hole := _hole_at(screen_position)
	if not hole.is_empty() and circuit.is_hole_free(hole):
		return hole
	return {}


func _free_column_hole(column: int, half: String) -> Dictionary:
	var rows := [0, 1, 2, 3, 4] if half == "top" else [5, 6, 7, 8, 9]
	for row: int in rows:
		var hole := {"column": column, "row": row}
		if circuit.is_hole_free(hole):
			return hole
	return {}


# Finds the nearest breadboard hole (terminal or rail) to a screen point.
func _hole_at(screen_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 1000000.0
	var threshold := maxf(9.0, 11.0 * zoom)

	for column: int in range(BREADBOARD_COLUMNS):
		for row_index: int in range(10):
			var distance := _breadboard_hole_screen_position(column, row_index).distance_squared_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best = {"column": column, "row": row_index}

	var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
	var rail_specs := [["top", "plus"], ["top", "minus"], ["bottom", "plus"], ["bottom", "minus"]]
	for spec: Array in rail_specs:
		var points := _rail_bus_points(board_rect, spec[0], spec[1])
		for index: int in range(points.size()):
			var distance := points[index].distance_squared_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best = {"rail": "%s:%s" % [spec[0], spec[1]], "index": index}

	return best if best_distance <= threshold * threshold else {}


func _hole_screen_position(hole: Dictionary) -> Vector2:
	if hole.has("rail"):
		var parts := String(hole["rail"]).split(":")
		if parts.size() < 2:
			return Vector2.ZERO
		var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
		var points := _rail_bus_points(board_rect, parts[0], parts[1])
		var index := int(hole.get("index", 0))
		return points[index] if index >= 0 and index < points.size() else Vector2.ZERO
	return _breadboard_hole_screen_position(int(hole.get("column", 0)), int(hole.get("row", 0)))


func _wire_net_id(wire: Dictionary) -> int:
	if not circuit:
		return -1
	return circuit.net_id_for_bus(circuit.hole_bus_id(wire["start"]))


func _cancel_transient_tool_state() -> void:
	_wire_start.clear()
	_hovered_hole.clear()
	_has_placement_ghost = false
	queue_redraw()


func _selected_part_definition():
	if selected_part_id == &"" or not library.has(selected_part_id):
		return null
	return library[selected_part_id]


func _snap_new_chip_to_breadboard(chip, definition, screen_position: Vector2) -> void:
	if _is_dip_definition(definition):
		var column := clampi(_nearest_breadboard_column(screen_position) - 3, 0, BREADBOARD_COLUMNS - 7)
		chip.state["dip_origin_column"] = column
		return

	var first_pin_name: StringName = definition.pins[0].get("name")
	var hole := _nearest_breadboard_hole(screen_position)
	if not hole.is_empty():
		chip.state["pin_holes"] = {
			str(first_pin_name): hole,
		}


func _is_dip_definition(definition) -> bool:
	return definition.id in [&"ic_7400", &"ic_7404", &"ic_7486", &"ic_7408", &"ic_7432"]


func _nearest_breadboard_column(screen_position: Vector2) -> int:
	var best_column := 0
	var best_distance := 1000000.0
	for column: int in range(BREADBOARD_COLUMNS):
		for row_index: int in range(10):
			var distance := _breadboard_hole_screen_position(column, row_index).distance_squared_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best_column = column
	return best_column


func _nearest_breadboard_hole(screen_position: Vector2) -> Dictionary:
	var best := {}
	var best_distance := 1000000.0
	for column: int in range(BREADBOARD_COLUMNS):
		for row_index: int in range(10):
			var distance := _breadboard_hole_screen_position(column, row_index).distance_squared_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best = {"column": column, "row": row_index}
	return best


func _snapped_grid_position_for_definition(screen_position: Vector2, definition) -> Vector2i:
	var component_size := _component_size_for_definition(definition)
	var world_top_left := _screen_to_world(screen_position) - component_size * 0.5
	return Vector2i(
		int(round(world_top_left.x / GRID_SPACING)),
		int(round(world_top_left.y / GRID_SPACING))
	)


func _next_chip_label(definition) -> String:
	var prefix := _chip_label_prefix(definition.id)
	var next_number := 1
	while _chip_label_exists("%s%d" % [prefix, next_number]):
		next_number += 1
	return "%s%d" % [prefix, next_number]


func _chip_label_prefix(definition_id: StringName) -> String:
	match definition_id:
		&"power_5v":
			return "5V"
		&"ground":
			return "GND"
		&"toggle":
			return "IN"
		&"switch":
			return "SW"
		&"led":
			return "LED"
		&"resistor_2k2", &"resistor_220":
			return "R"
	return "U"


func _chip_label_exists(label: String) -> bool:
	if not circuit:
		return false
	for chip in circuit.chips:
		if chip.label == label:
			return true
	return false


func _next_wire_net_label() -> String:
	while _net_label_exists("NET%d" % _next_wire_net_number):
		_next_wire_net_number += 1

	var label := "NET%d" % _next_wire_net_number
	_next_wire_net_number += 1
	return label


func _net_label_exists(net_label: String) -> bool:
	if not circuit:
		return false
	for net in circuit.nets:
		if net.label == net_label:
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.73, 0.70), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 96.0)), Color(0.86, 0.84, 0.73, 0.26), true)
	_draw_grid()
	_draw_breadboard()

	if not circuit:
		return

	# Jumper wires first, with the hovered net's wires drawn last so they sit on top.
	for wire: Dictionary in circuit.wires:
		if _wire_net_id(wire) != _hovered_net_id:
			_draw_jumper(wire)
	for wire: Dictionary in circuit.wires:
		if _wire_net_id(wire) == _hovered_net_id:
			_draw_jumper(wire)

	if _hovered_net_id >= 0 and _hovered_net_id < circuit.nets.size():
		_draw_net_highlight(circuit.nets[_hovered_net_id])

	for net in circuit.nets:
		if net.id != _hovered_net_id and _should_label_net(net.label) and zoom >= 1.18:
			_draw_net_label(net)

	for chip in circuit.chips:
		_draw_chip(chip)

	if active_tool == TOOL_PLACE:
		_draw_placement_ghost()
	elif active_tool == TOOL_WIRE:
		_draw_wire_tool_overlay()


func _draw_jumper(wire: Dictionary) -> void:
	var start := _hole_screen_position(wire["start"])
	var end := _hole_screen_position(wire["end"])
	var net_id := _wire_net_id(wire)
	var net = circuit.nets[net_id] if net_id >= 0 and net_id < circuit.nets.size() else null
	var color := _wire_color_for_net(net) if net else WIRE_COLORS[0]
	var label: String = net.label if net else ""
	var highlighted: bool = net_id >= 0 and net_id == _hovered_net_id
	if highlighted:
		color = color.lightened(0.22)
	var line_width: float = maxf(2.8, 4.2 * zoom) * (1.45 if highlighted else 1.0)
	_draw_wire(start, end, color, line_width, label, 1, 1, highlighted)


func _draw_net_highlight(net) -> void:
	var color := _wire_color_for_net(net)
	for connection: Dictionary in _net_connections(net):
		if connection.has("bus"):
			_draw_bus_connection(connection, color, true)
	_draw_net_label(net)


func _draw_grid() -> void:
	var step := GRID_SPACING * zoom
	if step < 8.0:
		return

	var origin := size * 0.5 + pan
	var start_x := fposmod(origin.x, step)
	var start_y := fposmod(origin.y, step)
	var grid_color := Color(0.55, 0.58, 0.56, 0.22)
	var axis_color := Color(0.42, 0.45, 0.43, 0.45)

	var x := start_x
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), axis_color if absf(x - origin.x) < 1.0 else grid_color, 1.0)
		x += step

	var y := start_y
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), axis_color if absf(y - origin.y) < 1.0 else grid_color, 1.0)
		y += step


func _draw_breadboard() -> void:
	var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
	var board_radius := 18.0 * zoom
	_draw_rounded_rect(
		_offset_rect(board_rect, Vector2(0.0, 8.0 * zoom)),
		Color(0.42, 0.36, 0.25, 0.35),
		Color.TRANSPARENT,
		0.0,
		board_radius
	)
	_draw_rounded_rect(board_rect, Color(0.88, 0.88, 0.84), Color(0.52, 0.50, 0.43), 2.0 * zoom, board_radius)
	_draw_rounded_rect(_inset_rect(board_rect, 10.0 * zoom), Color(0.94, 0.94, 0.90), Color(0.75, 0.74, 0.67), 1.0 * zoom, 9.0 * zoom)
	_draw_bb830_labels(board_rect)
	_draw_bb830_rails(board_rect)
	_draw_bb830_terminal_strips(board_rect)


func _draw_bb830_labels(board_rect: Rect2) -> void:
	var font := get_theme_default_font()
	var dark := Color(0.12, 0.12, 0.105, 0.86)
	var red := Color(0.72, 0.07, 0.06)
	var row_letters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
	var x_left := _bb830_column_x(board_rect, 0) - 36.0 * zoom
	var x_right := _bb830_column_x(board_rect, BREADBOARD_COLUMNS - 1) + 24.0 * zoom
	var rail_label_x := board_rect.position.x + 20.0 * zoom

	draw_string(font, Vector2(rail_label_x, _bb830_rail_y(board_rect, "top", "plus") + 8.0 * zoom), "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(16, int(24 * zoom)), red)
	draw_string(font, Vector2(rail_label_x, _bb830_rail_y(board_rect, "top", "minus") + 8.0 * zoom), "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(14, int(21 * zoom)), dark)
	draw_string(font, Vector2(rail_label_x, _bb830_rail_y(board_rect, "bottom", "plus") + 8.0 * zoom), "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(16, int(24 * zoom)), red)
	draw_string(font, Vector2(rail_label_x, _bb830_rail_y(board_rect, "bottom", "minus") + 8.0 * zoom), "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(14, int(21 * zoom)), dark)
	draw_string(font, Vector2(board_rect.position.x + 18.0 * zoom, _bb830_center_groove_y(board_rect) + 6.0 * zoom), "BB830", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(10, int(15 * zoom)), dark)

	for index: int in range(row_letters.size()):
		var row_y := _bb830_row_y(board_rect, index)
		draw_string(font, Vector2(x_left, row_y + 4.0 * zoom), row_letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(8, int(10 * zoom)), dark)
		draw_string(font, Vector2(x_right, row_y + 4.0 * zoom), row_letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(8, int(10 * zoom)), dark)

	var label_columns := [0, 4, 9, 14, 19, 24, 29, 34, 39, 44, 49, 51]
	for column in label_columns:
		var x := _bb830_column_x(board_rect, int(column))
		var label := str(int(column) + 1)
		draw_string(font, Vector2(x, _bb830_row_y(board_rect, 0) - 25.0 * zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 34.0 * zoom, max(8, int(12 * zoom)), dark)
		draw_string(font, Vector2(x, _bb830_row_y(board_rect, 9) + 35.0 * zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 34.0 * zoom, max(8, int(12 * zoom)), dark)


func _draw_bb830_rails(board_rect: Rect2) -> void:
	var rail_width := maxf(1.6, 2.3 * zoom)
	var red := Color(0.75, 0.09, 0.07, 0.85)
	var black := Color(0.06, 0.06, 0.055, 0.92)
	var rail_specs := [
		{"side": "top", "polarity": "plus", "color": red},
		{"side": "top", "polarity": "minus", "color": black},
		{"side": "bottom", "polarity": "plus", "color": red},
		{"side": "bottom", "polarity": "minus", "color": black},
	]

	for rail: Dictionary in rail_specs:
		var rail_points := _rail_bus_points(board_rect, rail["side"], rail["polarity"])
		if rail_points.is_empty():
			continue

		var accent: Color = rail["color"]
		draw_line(rail_points[0], rail_points[rail_points.size() - 1], accent, rail_width, true)
		for point: Vector2 in rail_points:
			_draw_breadboard_hole(point, accent)


func _draw_bb830_terminal_strips(board_rect: Rect2) -> void:
	_draw_bb830_terminal_band(board_rect, 0, 4)
	_draw_bb830_terminal_band(board_rect, 5, 9)

	for column: int in range(BREADBOARD_COLUMNS):
		var x := _bb830_column_x(board_rect, column)
		for row: int in range(5):
			_draw_breadboard_hole(Vector2(x, _bb830_row_y(board_rect, row)))
			_draw_breadboard_hole(Vector2(x, _bb830_row_y(board_rect, row + 5)))

	var groove_y := _bb830_center_groove_y(board_rect)
	draw_line(
		Vector2(_bb830_column_x(board_rect, 0) - 24.0 * zoom, groove_y),
		Vector2(_bb830_column_x(board_rect, BREADBOARD_COLUMNS - 1) + 24.0 * zoom, groove_y),
		Color(0.55, 0.55, 0.50, 0.45),
		maxf(2.0, 9.0 * zoom),
		true
	)
	draw_line(
		Vector2(_bb830_column_x(board_rect, 0) - 24.0 * zoom, groove_y - 3.0 * zoom),
		Vector2(_bb830_column_x(board_rect, BREADBOARD_COLUMNS - 1) + 24.0 * zoom, groove_y - 3.0 * zoom),
		Color(0.98, 0.98, 0.94, 0.68),
		maxf(1.0, 1.2 * zoom),
		true
	)


func _draw_bb830_terminal_band(board_rect: Rect2, first_row: int, last_row: int) -> void:
	var first_y := _bb830_row_y(board_rect, first_row)
	var last_y := _bb830_row_y(board_rect, last_row)
	var band_rect := Rect2(
		Vector2(_bb830_column_x(board_rect, 0) - 17.0 * zoom, first_y - 15.0 * zoom),
		Vector2(
			_bb830_column_x(board_rect, BREADBOARD_COLUMNS - 1) - _bb830_column_x(board_rect, 0) + 34.0 * zoom,
			last_y - first_y + 30.0 * zoom
		)
	)
	_draw_rounded_rect(band_rect, Color(0.91, 0.91, 0.86, 0.64), Color(0.78, 0.77, 0.69, 0.48), 1.0 * zoom, 7.0 * zoom)


func _draw_breadboard_hole(position: Vector2, accent: Color = Color(0.53, 0.53, 0.49)) -> void:
	var outer := Rect2(position - Vector2(4.0, 4.0) * zoom, Vector2(8.0, 8.0) * zoom)
	var inner := Rect2(position - Vector2(2.4, 2.4) * zoom, Vector2(4.8, 4.8) * zoom)
	_draw_rounded_rect(outer, Color(0.82, 0.82, 0.78), accent.darkened(0.18), 0.6 * zoom, 1.7 * zoom)
	_draw_rounded_rect(inner, Color(0.07, 0.065, 0.055), Color(0.02, 0.02, 0.018), 0.0, 1.0 * zoom)


func _bb830_row_y(board_rect: Rect2, row_index: int) -> float:
	if row_index < 5:
		return board_rect.position.y + (BREADBOARD_TOP_TERMINAL_Y + BREADBOARD_HOLE_PITCH * row_index) * zoom
	return board_rect.position.y + (BREADBOARD_BOTTOM_TERMINAL_Y + BREADBOARD_HOLE_PITCH * (row_index - 5)) * zoom


func _bb830_column_x(board_rect: Rect2, column: int) -> float:
	return board_rect.position.x + (BREADBOARD_COLUMN_LEFT + BREADBOARD_HOLE_PITCH * column) * zoom


func _bb830_center_groove_y(board_rect: Rect2) -> float:
	return (_bb830_row_y(board_rect, 4) + _bb830_row_y(board_rect, 5)) * 0.5


func _bb830_rail_y(board_rect: Rect2, side: String, polarity: String) -> float:
	if side == "top" and polarity == "minus":
		return board_rect.position.y + BREADBOARD_TOP_MINUS_Y * zoom
	if side == "bottom" and polarity == "plus":
		return board_rect.position.y + BREADBOARD_BOTTOM_PLUS_Y * zoom
	if side == "bottom" and polarity == "minus":
		return board_rect.position.y + BREADBOARD_BOTTOM_MINUS_Y * zoom
	return board_rect.position.y + BREADBOARD_TOP_PLUS_Y * zoom


func _draw_power_rail(rect: Rect2, title: String, subtitle: String, accent: Color) -> void:
	var font := get_theme_default_font()
	_draw_rounded_rect(rect, Color(0.90, 0.86, 0.72), Color(0.61, 0.57, 0.45), 1.3 * zoom, 8.0 * zoom)

	var title_rect := Rect2(rect.position + Vector2(8.0, 8.0) * zoom, Vector2(rect.size.x - 16.0 * zoom, 26.0 * zoom))
	var title_size: int = maxi(10, int(14 * zoom))
	_draw_rounded_rect(title_rect, accent, accent.darkened(0.35), 1.1 * zoom, 4.0 * zoom)
	_draw_centered_text(font, title_rect, title, title_size, Color(0.98, 0.96, 0.86))

	var subtitle_rect := Rect2(rect.position + Vector2(20.0, 42.0) * zoom, Vector2(rect.size.x - 40.0 * zoom, 23.0 * zoom))
	_draw_rounded_rect(subtitle_rect, accent, accent.darkened(0.35), 1.1 * zoom, 4.0 * zoom)
	_draw_centered_text(font, subtitle_rect, subtitle, max(10, int(15 * zoom)), Color(0.98, 0.96, 0.86))

	var column_x := [rect.position.x + rect.size.x * 0.36, rect.position.x + rect.size.x * 0.68]
	var top := rect.position.y + 83.0 * zoom
	var bottom := rect.end.y - 26.0 * zoom
	for x: float in column_x:
		draw_line(Vector2(x, top), Vector2(x, bottom), accent, maxf(2.0, 3.0 * zoom), true)

	var rows := 8
	var usable_height := bottom - top
	for row in rows:
		var y := top + usable_height * (float(row) / float(rows - 1))
		draw_line(Vector2(column_x[0], y), Vector2(column_x[1], y), accent, maxf(2.0, 3.0 * zoom), true)
		for x: float in column_x:
			_draw_socket(Vector2(x, y), accent)


func _draw_signal_lanes(rect: Rect2) -> void:
	var font := get_theme_default_font()
	_draw_rounded_rect(rect, Color(0.91, 0.87, 0.73), Color(0.61, 0.57, 0.45), 1.3 * zoom, 8.0 * zoom)

	var header_rect := Rect2(rect.position + Vector2(10.0, 9.0) * zoom, Vector2(rect.size.x - 20.0 * zoom, 25.0 * zoom))
	_draw_rounded_rect(header_rect, Color(0.08, 0.51, 0.15), Color(0.04, 0.31, 0.09), 1.1 * zoom, 4.0 * zoom)
	_draw_centered_text(font, header_rect, "SIGNAL LINES", max(11, int(17 * zoom)), Color(0.98, 0.96, 0.86))

	var row_count := 8
	var row_top := rect.position.y + 58.0 * zoom
	var row_gap := (rect.size.y - 86.0 * zoom) / float(row_count - 1)
	var label_width := 29.0 * zoom
	var half_gap := 34.0 * zoom
	var hole_gap := 16.0 * zoom
	var row_height := 20.0 * zoom
	var left_start := rect.position.x + 62.0 * zoom
	var left_width := (rect.size.x - 94.0 * zoom - half_gap) * 0.5
	var right_start := left_start + left_width + half_gap

	for row in row_count:
		var y := row_top + row_gap * row
		var label_rect := Rect2(Vector2(rect.position.x + 17.0 * zoom, y - row_height * 0.5), Vector2(label_width, row_height))
		_draw_rounded_rect(label_rect, Color(0.10, 0.50, 0.16), Color(0.04, 0.31, 0.09), 1.0 * zoom, 4.0 * zoom)
		_draw_centered_text(font, label_rect, str(row + 1), max(9, int(13 * zoom)), Color(0.98, 0.96, 0.86))
		_draw_socket_row(Rect2(Vector2(left_start, y - 8.0 * zoom), Vector2(left_width, 16.0 * zoom)), hole_gap)
		_draw_socket_row(Rect2(Vector2(right_start, y - 8.0 * zoom), Vector2(left_width, 16.0 * zoom)), hole_gap)


func _draw_socket_row(rect: Rect2, hole_gap: float) -> void:
	_draw_rounded_rect(rect, Color(0.22, 0.69, 0.26), Color(0.07, 0.42, 0.12), 1.0 * zoom, 4.0 * zoom)

	var count: int = maxi(2, int(rect.size.x / hole_gap))
	var start_x := rect.position.x + (rect.size.x - float(count - 1) * hole_gap) * 0.5
	for index in count:
		_draw_socket(Vector2(start_x + index * hole_gap, rect.position.y + rect.size.y * 0.5), Color(0.08, 0.42, 0.11))


func _draw_socket(position: Vector2, accent: Color) -> void:
	var outer := Rect2(position - Vector2(5.0, 5.0) * zoom, Vector2(10.0, 10.0) * zoom)
	var inner := Rect2(position - Vector2(3.3, 3.3) * zoom, Vector2(6.6, 6.6) * zoom)
	_draw_rounded_rect(outer, accent.lightened(0.18), accent.darkened(0.30), 0.8 * zoom, 1.7 * zoom)
	_draw_rounded_rect(inner, Color(0.015, 0.018, 0.014), Color(0.16, 0.18, 0.14, 0.75), 0.6 * zoom, 1.2 * zoom)


func _draw_net_label(net) -> void:
	if net.label.is_empty():
		return

	var connections: Array[Dictionary] = _net_connections(net)
	if connections.is_empty():
		return

	var highlighted: bool = net.id == _hovered_net_id
	var points: Array[Vector2] = []
	for connection: Dictionary in connections:
		points.append(connection["position"])

	var font := get_theme_default_font()
	var font_size: int = max(10, int((13 if highlighted else 11) * zoom))
	var midpoint: Vector2 = (points[0] + points[points.size() - 1]) * 0.5
	var text := "%s=%s" % [net.label, _net_value_label(net)]
	var label_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var label_rect := Rect2(midpoint + Vector2(8.0, -25.0) * zoom, label_size + Vector2(16.0, 8.0) * zoom)
	_draw_rounded_rect(label_rect, Color(0.08, 0.09, 0.08, 0.94), SignalValue.color(net.value), (2.0 if highlighted else 1.0) * zoom, 4.0 * zoom)
	draw_string(font, label_rect.position + Vector2(8.0 * zoom, label_rect.size.y * 0.5 + font_size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.96, 0.95, 0.88))



func _draw_bus_connection(connection: Dictionary, color: Color, highlighted: bool) -> void:
	var points: Array[Vector2] = connection.get("points", [])
	if points.is_empty():
		return
	if not highlighted:
		return

	var width := maxf(2.0, 2.6 * zoom) * (1.45 if highlighted else 1.0)
	if points.size() > 1:
		draw_polyline(PackedVector2Array(points), Color(color.r, color.g, color.b, 0.34 if highlighted else 0.22), width + 7.0 * zoom, true)
		draw_polyline(PackedVector2Array(points), color, width, true)

	for point: Vector2 in points:
		draw_circle(point, (6.6 if highlighted else 5.0) * zoom, Color(color.r, color.g, color.b, 0.42 if highlighted else 0.28))
		draw_circle(point, (2.8 if highlighted else 2.2) * zoom, color.lightened(0.25))


func _net_connections(net) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	for connection: Dictionary in net.connections:
		if connection.has("bus"):
			var bus_id: String = connection["bus"]
			var bus_points := _bus_connection_points(bus_id)
			if bus_points.is_empty():
				continue
			connections.append({
				"bus": bus_id,
				"position": _average_points(bus_points),
				"points": bus_points,
				"direction": &"passive",
			})
			continue

		var chip = connection.get("chip")
		var pin_name: StringName = connection.get("pin")
		if chip == null:
			continue
		connections.append({
			"chip": chip,
			"pin": pin_name,
			"position": _pin_position(chip, pin_name),
			"direction": _pin_direction(chip, pin_name),
		})
	return connections


func _set_hovered_net(net_id: int) -> void:
	if _hovered_net_id == net_id:
		return

	_hovered_net_id = net_id
	queue_redraw()


func _hover_net_at(screen_position: Vector2) -> int:
	if not circuit:
		return -1

	var best_net_id := -1
	var best_distance := 1000000.0
	var threshold := maxf(8.0, 10.0 * zoom)

	for net in circuit.nets:
		if net.connections.size() < 2:
			continue

		var distance: float = _net_hit_distance(net, screen_position)
		if distance < best_distance:
			best_distance = distance
			best_net_id = net.id

	return best_net_id if best_distance <= threshold else -1


func _net_hit_distance(net, screen_position: Vector2) -> float:
	var best_distance := 1000000.0

	for wire: Dictionary in circuit.wires:
		if _wire_net_id(wire) != net.id:
			continue
		var start := _hole_screen_position(wire["start"])
		var end := _hole_screen_position(wire["end"])
		best_distance = minf(
			best_distance,
			_distance_to_polyline(screen_position, _wire_curve_points(start, end, net.label, 1, 1))
		)

	for connection: Dictionary in _net_connections(net):
		if connection.has("bus"):
			best_distance = minf(best_distance, _distance_to_bus_connection(connection, screen_position))

	return best_distance


func _distance_to_bus_connection(connection: Dictionary, screen_position: Vector2) -> float:
	var points: Array[Vector2] = connection.get("points", [])
	if points.is_empty():
		return 1000000.0
	if points.size() == 1:
		return points[0].distance_to(screen_position)
	return _distance_to_polyline(screen_position, PackedVector2Array(points))


func _distance_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	if points.size() < 2:
		return 1000000.0

	var best_distance := 1000000.0
	for index: int in range(1, points.size()):
		best_distance = minf(best_distance, _distance_to_segment(point, points[index - 1], points[index]))
	return best_distance


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)

	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest := start + segment * t
	return point.distance_to(closest)


func _expanded_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position - Vector2(amount, amount), rect.size + Vector2(amount * 2.0, amount * 2.0))


func _bb830_hole_position(board_rect: Rect2, column: int, row_index: int) -> Vector2:
	return Vector2(_bb830_column_x(board_rect, column), _bb830_row_y(board_rect, row_index))


func _bus_connection_points(bus_id: String) -> Array[Vector2]:
	var parts := bus_id.split(":")
	if parts.is_empty():
		return []

	var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
	match parts[0]:
		"terminal":
			if parts.size() < 3:
				return []
			var column := int(parts[1])
			var half := parts[2]
			return _terminal_bus_points(board_rect, column, half)
		"rail":
			if parts.size() < 3:
				return []
			return _rail_bus_points(board_rect, parts[1], parts[2])
	return []


func _terminal_bus_points(board_rect: Rect2, column: int, half: String) -> Array[Vector2]:
	if column < 0 or column >= BREADBOARD_COLUMNS:
		return []

	var points: Array[Vector2] = []
	var row_start := 5 if half == "bottom" else 0
	for row_offset: int in range(5):
		points.append(_bb830_hole_position(board_rect, column, row_start + row_offset))
	return points


func _rail_bus_points(board_rect: Rect2, side: String, polarity: String) -> Array[Vector2]:
	var rail_left := _bb830_column_x(board_rect, 0)
	var rail_right := _bb830_column_x(board_rect, BREADBOARD_COLUMNS - 1)
	var y := _bb830_rail_y(board_rect, side, polarity)

	var points: Array[Vector2] = []
	var gap := (rail_right - rail_left) / float(RAIL_HOLE_COUNT - 1)
	for index: int in range(RAIL_HOLE_COUNT):
		points.append(Vector2(rail_left + gap * index, y))
	return points


func _average_points(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO

	var total := Vector2.ZERO
	for point: Vector2 in points:
		total += point
	return total / float(points.size())


func _pin_direction(chip, pin_name: StringName) -> StringName:
	var pin: Dictionary = chip.definition.get_pin(pin_name)
	return pin.get("direction", &"passive")


func _pin_net_label(chip, pin_name: StringName) -> String:
	var net_id: int = chip.pin_nets.get(pin_name, -1)
	if net_id < 0 or not circuit or net_id >= circuit.nets.size():
		return ""
	return circuit.nets[net_id].label


func _pin_display_color(value: int, net_label: String) -> Color:
	match net_label:
		"VCC":
			return Color(0.86, 0.08, 0.06)
		"GND":
			return Color(0.02, 0.02, 0.018)
	return SignalValue.color(value)


func _net_value_label(net) -> String:
	match net.label:
		"VCC":
			return "5V"
		"GND":
			return "0V"
	return SignalValue.label(net.value)


func _draw_wire(start: Vector2, end: Vector2, color: Color, width: float, net_label: String, connection_index: int, wire_count: int, highlighted: bool) -> void:
	var points := _wire_curve_points(start, end, net_label, connection_index, wire_count)
	if highlighted:
		draw_polyline(points, Color(color.r, color.g, color.b, 0.30), width + 10.0 * zoom, true)
	draw_polyline(points, Color(0.06, 0.05, 0.04, 0.34), width + 5.0 * zoom, true)
	draw_polyline(points, color.darkened(0.20), width + 1.6 * zoom, true)
	draw_polyline(points, color, width, true)
	draw_polyline(points, color.lightened(0.48 if highlighted else 0.34), maxf(1.0, width * (0.24 if highlighted else 0.18)), true)
	draw_circle(start, width * 0.50, Color(0.06, 0.06, 0.055))
	draw_circle(end, width * 0.50, Color(0.06, 0.06, 0.055))
	draw_circle(start, width * 0.32, color.lightened(0.12))
	draw_circle(end, width * 0.32, color.lightened(0.12))


func _wire_curve_points(start: Vector2, end: Vector2, net_label: String, connection_index: int, wire_count: int) -> PackedVector2Array:
	var chord := end - start
	var distance := chord.length()
	if distance < 1.0:
		return PackedVector2Array([start, end])

	var direction := chord / distance
	var normal := Vector2(-direction.y, direction.x)
	var centered := float(connection_index - 1) - float(wire_count - 1) * 0.5
	var bias := _wire_curve_bias(net_label)
	var side_offset := normal * centered * 22.0 * zoom + Vector2(bias.x * zoom, 0.0)
	var sag := clampf(distance * 0.11, 14.0 * zoom, 58.0 * zoom)
	sag += absf(centered) * 5.0 * zoom + float(connection_index - 1) * 6.0 * zoom + bias.y * zoom

	var control_distance := distance * 0.30
	var control_1 := start + direction * control_distance + side_offset * 0.45 + Vector2(0.0, sag)
	var control_2 := end - direction * control_distance + side_offset * 0.55 + Vector2(0.0, sag)
	var wobble := _wire_wobble(net_label, connection_index) * zoom
	var steps: int = mini(maxi(int(distance / (16.0 * zoom)), 12), 36)
	var points := PackedVector2Array()

	for step: int in range(steps + 1):
		var t := float(step) / float(steps)
		var point := _cubic_bezier(start, control_1, control_2, end, t)
		point += normal * sin(t * PI) * wobble
		points.append(point)

	return points


func _cubic_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return (
		a * inverse * inverse * inverse
		+ b * 3.0 * inverse * inverse * t
		+ c * 3.0 * inverse * t * t
		+ d * t * t * t
	)


func _wire_curve_bias(net_label: String) -> Vector2:
	match net_label:
		"A":
			return Vector2(-9.0, 0.0)
		"B":
			return Vector2(7.0, 8.0)
		"Cin":
			return Vector2(-18.0, 16.0)
		"A xor B":
			return Vector2(0.0, -4.0)
		"A and B":
			return Vector2(10.0, 18.0)
		"(A xor B) and Cin":
			return Vector2(-7.0, 11.0)
		"SUM":
			return Vector2(6.0, 24.0)
		"Cout":
			return Vector2(-6.0, -6.0)
	return Vector2.ZERO


func _wire_wobble(net_label: String, connection_index: int) -> float:
	var seed := connection_index * 17 + net_label.length() * 5
	return float((seed % 7) - 3) * 1.8


func _draw_chip(chip) -> void:
	var rect: Rect2 = _chip_rect(chip)
	match chip.definition.id:
		&"power_5v", &"ground":
			_draw_supply_terminal(chip, rect)
		&"toggle":
			_draw_toggle(chip, rect)
		&"switch":
			_draw_switch(chip, rect)
		&"led":
			_draw_led(chip, rect)
		&"resistor_2k2", &"resistor_220":
			_draw_resistor(chip, rect)
		_:
			_draw_dip_chip(chip, rect)

	for pin: Dictionary in chip.definition.pins:
		_draw_pin(chip, pin)


func _draw_dip_chip(chip, rect: Rect2) -> void:
	var font := get_theme_default_font()
	var title_size: int = max(11, int(15 * zoom))
	var label_size: int = max(9, int(12 * zoom))
	var body_rect := _inset_rect(rect, 11.0 * zoom)

	_draw_chip_shadow(rect)
	_draw_dip_legs(chip, body_rect)
	_draw_rounded_rect(body_rect, Color(0.025, 0.027, 0.026), Color(0.0, 0.0, 0.0), 2.0 * zoom, 8.0 * zoom)
	_draw_rounded_rect(_inset_rect(body_rect, 5.0 * zoom), chip.definition.tint.lightened(0.10), Color(0.16, 0.17, 0.16), 1.0 * zoom, 4.0 * zoom)

	var notch_center := body_rect.position + Vector2(17.0, body_rect.size.y * 0.5 / zoom) * zoom
	draw_circle(notch_center, 12.0 * zoom, Color(0.015, 0.016, 0.016))
	draw_arc(notch_center, 12.0 * zoom, -PI * 0.45, PI * 0.45, 18, Color(0.25, 0.26, 0.24), maxf(1.0, zoom), true)

	var title: String = chip.label if not chip.label.is_empty() else chip.definition.display_name
	draw_string(font, body_rect.position + Vector2(37.0, 31.0) * zoom, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(0.92, 0.90, 0.82))
	draw_string(font, body_rect.position + Vector2(37.0, 54.0) * zoom, chip.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, Color(0.54, 0.57, 0.52))


func _draw_dip_legs(chip, body_rect: Rect2) -> void:
	for pin: Dictionary in chip.definition.pins:
		var pin_position := _pin_position(chip, pin.get("name"))
		var side: StringName = pin.get("side", &"left")
		var leg_size := Vector2(17.0, 8.0) * zoom
		var leg_rect := Rect2(pin_position - Vector2(0.0, leg_size.y * 0.5), leg_size)
		match side:
			&"left":
				leg_rect.position.x = body_rect.position.x - leg_size.x + 2.0 * zoom
			&"right":
				leg_rect.position.x = body_rect.end.x - 2.0 * zoom
			&"top":
				leg_size = Vector2(8.0, 17.0) * zoom
				leg_rect = Rect2(pin_position - Vector2(leg_size.x * 0.5, leg_size.y), leg_size)
				leg_rect.position.y = body_rect.position.y - leg_size.y + 2.0 * zoom
			&"bottom":
				leg_size = Vector2(8.0, 17.0) * zoom
				leg_rect = Rect2(pin_position - Vector2(leg_size.x * 0.5, 0.0), leg_size)
				leg_rect.position.y = body_rect.end.y - 2.0 * zoom
			_:
				continue
		_draw_rounded_rect(leg_rect, Color(0.77, 0.77, 0.70), Color(0.34, 0.35, 0.33), 1.0 * zoom, 2.0 * zoom)
		if side in [&"top", &"bottom"]:
			draw_line(leg_rect.position + Vector2(2.0, 3.0) * zoom, leg_rect.position + Vector2(2.0 * zoom, leg_rect.size.y - 3.0 * zoom), Color(0.96, 0.96, 0.90, 0.65), maxf(1.0, zoom), true)
		else:
			draw_line(leg_rect.position + Vector2(3.0, 2.0) * zoom, leg_rect.position + Vector2(leg_rect.size.x - 3.0 * zoom, 2.0 * zoom), Color(0.96, 0.96, 0.90, 0.65), maxf(1.0, zoom), true)


func _draw_toggle(chip, rect: Rect2) -> void:
	var is_on: bool = chip.state.get("on", false)
	var font := get_theme_default_font()
	var title_size: int = max(9, int(12 * zoom))
	var label_size: int = max(8, int(9 * zoom))
	var accent := SignalValue.color(SignalValue.State.HIGH if is_on else SignalValue.State.LOW)

	_draw_chip_shadow(rect)
	_draw_rounded_rect(rect, Color(0.88, 0.88, 0.84), Color(0.48, 0.48, 0.43), 1.4 * zoom, 4.0 * zoom)

	var title: String = chip.label if not chip.label.is_empty() else chip.definition.display_name
	draw_string(font, rect.position + Vector2(0.0, -8.0) * zoom, title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_size, Color(0.12, 0.13, 0.12))

	var cap_rect := _inset_rect(rect, 9.0 * zoom)
	_draw_rounded_rect(_offset_rect(cap_rect, Vector2(0.0, 2.0 * zoom)), Color(0.04, 0.04, 0.04, 0.45), Color.TRANSPARENT, 0.0, 8.0 * zoom)
	_draw_rounded_rect(cap_rect, Color(0.03, 0.03, 0.03) if not is_on else Color(0.88, 0.88, 0.83), Color(0.0, 0.0, 0.0), 1.2 * zoom, 8.0 * zoom)
	draw_circle(cap_rect.position + Vector2(8.0, 8.0) * zoom, 4.0 * zoom, Color(1.0, 1.0, 1.0, 0.25))

	var state_rect := Rect2(rect.position + Vector2(rect.size.x - 20.0 * zoom, rect.size.y - 17.0 * zoom), Vector2(14.0, 11.0) * zoom)
	_draw_rounded_rect(state_rect, accent, accent.darkened(0.30), 0.8 * zoom, 3.0 * zoom)
	draw_string(font, rect.position + Vector2(0.0, rect.size.y + 12.0 * zoom), "INPUT", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color(0.28, 0.28, 0.24))


func _draw_switch(chip, rect: Rect2) -> void:
	var is_on: bool = chip.state.get("on", false)
	var font := get_theme_default_font()
	var label_size: int = max(8, int(9 * zoom))
	var leg_color := Color(0.74, 0.74, 0.68)
	var top_mid := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
	var bottom_mid := Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)

	# Legs reach from the body down to the two breadboard holes it straddles.
	if _is_spanning_switch(chip):
		draw_line(top_mid, _pin_position(chip, &"A"), leg_color, maxf(2.0, 2.6 * zoom), true)
		draw_line(bottom_mid, _pin_position(chip, &"B"), leg_color, maxf(2.0, 2.6 * zoom), true)

	_draw_chip_shadow(rect)
	_draw_rounded_rect(rect, Color(0.13, 0.13, 0.12), Color(0.02, 0.02, 0.02), 1.4 * zoom, 5.0 * zoom)

	var cap_center := rect.position + rect.size * 0.5
	var cap_radius := minf(rect.size.x, rect.size.y) * 0.30
	var cap_color := Color(0.16, 0.70, 0.26) if is_on else Color(0.78, 0.20, 0.16)
	draw_circle(cap_center + Vector2(0.0, (2.4 if not is_on else 0.6) * zoom), cap_radius, Color(0.04, 0.04, 0.04, 0.55))
	draw_circle(cap_center, cap_radius, cap_color)
	draw_circle(cap_center, cap_radius, cap_color.darkened(0.42), false, maxf(1.0, 1.4 * zoom))
	draw_circle(cap_center - Vector2(cap_radius * 0.32, cap_radius * 0.32), cap_radius * 0.34, Color(1.0, 1.0, 1.0, 0.22))

	var title: String = chip.label if not chip.label.is_empty() else chip.definition.display_name
	draw_string(font, Vector2(rect.position.x, rect.position.y - 7.0 * zoom), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, max(9, int(12 * zoom)), Color(0.12, 0.13, 0.12))
	draw_string(font, Vector2(rect.position.x, rect.end.y + 12.0 * zoom), "SW", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color(0.28, 0.28, 0.24))


func _draw_led(chip, rect: Rect2) -> void:
	var is_lit: bool = chip.state.get("lit", false)
	var font := get_theme_default_font()
	var title_size: int = max(9, int(12 * zoom))
	var label_size: int = max(8, int(9 * zoom))
	var led_center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.36)
	var is_carry: bool = chip.label.to_lower().contains("cout")
	var base_color := Color(0.05, 0.80, 0.18) if is_carry else Color(1.0, 0.06, 0.03)
	var led_color := base_color if is_lit else base_color.darkened(0.58)

	_draw_chip_shadow(rect)

	if is_lit:
		draw_circle(led_center, 27.0 * zoom, Color(base_color.r, base_color.g, base_color.b, 0.18))
		draw_circle(led_center, 18.0 * zoom, Color(base_color.r, base_color.g, base_color.b, 0.24))

	draw_line(led_center + Vector2(-9.0, 20.0) * zoom, led_center + Vector2(-9.0, 38.0) * zoom, Color(0.74, 0.74, 0.68), maxf(2.0, 2.8 * zoom), true)
	draw_line(led_center + Vector2(9.0, 20.0) * zoom, led_center + Vector2(9.0, 33.0) * zoom, Color(0.74, 0.74, 0.68), maxf(2.0, 2.8 * zoom), true)
	draw_circle(led_center, 18.0 * zoom, led_color)
	draw_circle(led_center, 18.0 * zoom, base_color.darkened(0.55), false, maxf(1.0, 2.0 * zoom))
	draw_circle(led_center + Vector2(-6.0, -7.0) * zoom, 4.5 * zoom, led_color.lightened(0.64))
	var title: String = chip.label if not chip.label.is_empty() else chip.definition.display_name
	draw_string(font, rect.position + Vector2(0.0, rect.size.y - 5.0 * zoom), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_size, Color(0.12, 0.13, 0.12))
	draw_string(font, rect.position + Vector2(0.0, rect.size.y + 11.0 * zoom), "LED", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color(0.28, 0.28, 0.24))


func _draw_resistor(chip, rect: Rect2) -> void:
	var font := get_theme_default_font()
	var center_y := rect.position.y + rect.size.y * 0.5
	var lead_color := Color(0.73, 0.73, 0.67)
	var body_rect := Rect2(rect.position + Vector2(20.0, 7.0) * zoom, rect.size - Vector2(40.0, 14.0) * zoom)
	draw_line(Vector2(rect.position.x, center_y), Vector2(body_rect.position.x, center_y), lead_color, maxf(2.0, 2.4 * zoom), true)
	draw_line(Vector2(body_rect.end.x, center_y), Vector2(rect.end.x, center_y), lead_color, maxf(2.0, 2.4 * zoom), true)
	_draw_rounded_rect(body_rect, Color(0.80, 0.58, 0.25), Color(0.42, 0.25, 0.08), 1.0 * zoom, 8.0 * zoom)

	var band_colors: Array[Color] = [
		Color(0.35, 0.14, 0.04),
		Color(0.35, 0.14, 0.04),
		Color(0.82, 0.04, 0.03) if chip.definition.id == &"resistor_2k2" else Color(0.35, 0.14, 0.04),
		Color(0.83, 0.65, 0.18),
	]
	for index: int in range(band_colors.size()):
		var x := body_rect.position.x + (12.0 + index * 12.0) * zoom
		draw_rect(Rect2(Vector2(x, body_rect.position.y + 1.0 * zoom), Vector2(4.0, body_rect.size.y - 2.0 * zoom)), band_colors[index], true)

	var label := "%s %s" % [chip.label, chip.definition.display_name]
	draw_string(font, rect.position + Vector2(0.0, -3.0 * zoom), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, max(8, int(9 * zoom)), Color(0.18, 0.16, 0.11))


func _draw_supply_terminal(chip, rect: Rect2) -> void:
	var is_power: bool = chip.definition.id == &"power_5v"
	var font := get_theme_default_font()
	var title: String = chip.label if not chip.label.is_empty() else chip.definition.display_name
	var accent := Color(0.86, 0.08, 0.06) if is_power else Color(0.02, 0.02, 0.018)
	var fill := Color(0.91, 0.88, 0.76) if is_power else Color(0.72, 0.72, 0.66)
	var symbol_center := rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.48)

	_draw_chip_shadow(rect)
	_draw_rounded_rect(rect, fill, Color(0.45, 0.43, 0.36), 1.4 * zoom, 4.0 * zoom)
	draw_circle(symbol_center, 13.0 * zoom, accent)
	draw_circle(symbol_center, 13.0 * zoom, Color(0.02, 0.02, 0.018), false, maxf(1.0, 1.2 * zoom))
	draw_line(symbol_center + Vector2(-6.0, 0.0) * zoom, symbol_center + Vector2(6.0, 0.0) * zoom, Color(0.98, 0.95, 0.82), maxf(1.2, 2.0 * zoom), true)
	if is_power:
		draw_line(symbol_center + Vector2(0.0, -6.0) * zoom, symbol_center + Vector2(0.0, 6.0) * zoom, Color(0.98, 0.95, 0.82), maxf(1.2, 2.0 * zoom), true)
	else:
		draw_line(symbol_center + Vector2(-7.0, 7.0) * zoom, symbol_center + Vector2(7.0, 7.0) * zoom, Color(0.98, 0.95, 0.82), maxf(1.2, 1.6 * zoom), true)
		draw_line(symbol_center + Vector2(-4.0, 11.0) * zoom, symbol_center + Vector2(4.0, 11.0) * zoom, Color(0.98, 0.95, 0.82), maxf(1.0, 1.3 * zoom), true)

	draw_string(font, rect.position + Vector2(0.0, rect.size.y + 12.0 * zoom), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, max(9, int(11 * zoom)), Color(0.15, 0.14, 0.11))


func _draw_pin(chip, pin: Dictionary) -> void:
	var pin_name: StringName = pin.get("name")
	var position := _pin_position(chip, pin_name)
	var value: int = circuit.read_pin(chip, pin_name)
	var net_label := _pin_net_label(chip, pin_name)
	var radius := maxf(3.2, 4.4 * zoom)
	var font := get_theme_default_font()
	var font_size: int = max(9, int(10 * zoom))
	var side: StringName = pin.get("side", &"left")
	var label_offset := Vector2(10.0, -7.0) * zoom
	match side:
		&"left":
			label_offset = Vector2(-26.0, -7.0) * zoom
		&"top":
			label_offset = Vector2(-6.0, -17.0) * zoom
		&"bottom":
			label_offset = Vector2(-6.0, 22.0) * zoom

	draw_circle(position + Vector2(1.5, 1.5) * zoom, radius + 1.0 * zoom, Color(0.04, 0.04, 0.035, 0.34))
	draw_circle(position, radius, _pin_display_color(value, net_label))
	draw_circle(position, radius, Color(0.04, 0.05, 0.045), false, maxf(1.0, 1.2 * zoom))
	draw_circle(position - Vector2(2.0, 2.0) * zoom, radius * 0.35, Color(1.0, 1.0, 0.92, 0.32))
	if zoom >= 1.25 and not [&"resistor_2k2", &"resistor_220", &"led", &"toggle", &"switch"].has(chip.definition.id):
		draw_string(font, position + label_offset, str(pin_name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.10, 0.11, 0.10))


func _draw_placement_ghost() -> void:
	if not _has_placement_ghost:
		return

	var definition = _selected_part_definition()
	if not definition:
		return

	var rect := _definition_rect(_ghost_grid_position, definition)
	var font := get_theme_default_font()
	var fill := Color(0.98, 0.80, 0.24, 0.20)
	var border := Color(0.95, 0.68, 0.14, 0.88)
	_draw_rounded_rect(_expanded_rect(rect, 4.0 * zoom), Color(fill.r, fill.g, fill.b, 0.11), Color.TRANSPARENT, 0.0, 8.0 * zoom)
	_draw_rounded_rect(rect, fill, border, maxf(1.0, 2.0 * zoom), 6.0 * zoom)
	_draw_centered_text(font, _inset_rect(rect, 6.0 * zoom), _definition_short_label(definition), max(10, int(13 * zoom)), Color(0.12, 0.10, 0.06))

	for pin: Dictionary in definition.pins:
		var pin_name: StringName = pin.get("name")
		var pin_position := _pin_position_for_definition(definition, rect, pin_name)
		draw_circle(pin_position, maxf(3.0, 4.2 * zoom), Color(0.98, 0.93, 0.72, 0.82))
		draw_circle(pin_position, maxf(3.0, 4.2 * zoom), border.darkened(0.40), false, maxf(1.0, 1.2 * zoom))


func _draw_wire_tool_overlay() -> void:
	if not _wire_start.is_empty():
		var start_position := _hole_screen_position(_wire_start)
		var end_position := _last_mouse_screen_position
		if not _hovered_hole.is_empty():
			end_position = _hole_screen_position(_hovered_hole)

		draw_line(start_position, end_position, Color(0.08, 0.07, 0.04, 0.36), maxf(4.0, 6.0 * zoom), true)
		draw_line(start_position, end_position, Color(0.96, 0.72, 0.18, 0.92), maxf(2.0, 3.0 * zoom), true)
		_draw_hole_tool_ring(_wire_start, Color(0.96, 0.72, 0.18))

	if not _hovered_hole.is_empty():
		_draw_hole_tool_ring(_hovered_hole, Color(0.23, 0.52, 0.96))


func _draw_hole_tool_ring(hole: Dictionary, color: Color) -> void:
	var position := _hole_screen_position(hole)
	draw_circle(position, maxf(8.0, 10.0 * zoom), Color(color.r, color.g, color.b, 0.15))
	draw_circle(position, maxf(5.8, 7.0 * zoom), color, false, maxf(1.3, 1.7 * zoom))
	draw_circle(position, maxf(2.5, 3.3 * zoom), color.lightened(0.30))


func _chip_rect(chip) -> Rect2:
	if _is_breadboard_dip(chip):
		return _breadboard_dip_rect(chip)
	if _is_spanning_switch(chip):
		return _spanning_switch_rect(chip)
	if _is_spanning_resistor(chip):
		return _spanning_resistor_rect(chip)
	if _has_any_pin_hole(chip):
		return _anchored_chip_rect(chip)

	var top_left := _world_to_screen(Vector2(chip.position) * GRID_SPACING)
	return Rect2(top_left, _component_size(chip) * zoom)


func _component_size(chip) -> Vector2:
	return _component_size_for_definition(chip.definition)


func _component_size_for_definition(definition) -> Vector2:
	match definition.id:
		&"power_5v", &"ground":
			return Vector2(60.0, 48.0)
		&"toggle":
			return Vector2(58.0, 48.0)
		&"switch":
			return Vector2(48.0, 58.0)
		&"led":
			return Vector2(68.0, 82.0)
		&"resistor_2k2", &"resistor_220":
			return Vector2(94.0, 30.0)
		&"ic_7400", &"ic_7404", &"ic_7486", &"ic_7408", &"ic_7432":
			return Vector2(160.0, 88.0)
		_:
			return CHIP_SIZE


func _definition_rect(grid_position: Vector2i, definition) -> Rect2:
	var top_left := _world_to_screen(Vector2(grid_position) * GRID_SPACING)
	return Rect2(top_left, _component_size_for_definition(definition) * zoom)


func _definition_short_label(definition) -> String:
	match definition.id:
		&"ic_7400":
			return "74LS00"
		&"ic_7404":
			return "74LS04"
		&"ic_7486":
			return "74LS86"
		&"ic_7408":
			return "74LS08"
		&"ic_7432":
			return "74LS32"
	return definition.display_name


func _chip_at(screen_position: Vector2):
	if not circuit:
		return null

	for index: int in range(circuit.chips.size() - 1, -1, -1):
		var chip = circuit.chips[index]
		if _chip_rect(chip).has_point(screen_position):
			return chip
	return null


func _pin_at(screen_position: Vector2) -> Dictionary:
	if not circuit:
		return {}

	var best_pin: Dictionary = {}
	var best_distance := 1000000.0
	var threshold := maxf(9.0, 11.0 * zoom)

	for chip_index: int in range(circuit.chips.size() - 1, -1, -1):
		var chip = circuit.chips[chip_index]
		for pin: Dictionary in chip.definition.pins:
			var pin_name: StringName = pin.get("name")
			var distance := _pin_position(chip, pin_name).distance_to(screen_position)
			if distance < best_distance:
				best_distance = distance
				best_pin = {"chip": chip, "pin": pin_name}

	return best_pin if best_distance <= threshold else {}


func _breadboard_hole_for_pin(chip, pin_name: StringName) -> Dictionary:
	var pin_holes: Dictionary = chip.state.get("pin_holes", {})
	if pin_holes.has(str(pin_name)):
		var hole: Dictionary = pin_holes[str(pin_name)]
		return {"column": int(hole.get("column", 0)), "row": int(hole.get("row", 0))}

	if not _is_breadboard_dip(chip):
		return {}

	var pin_number := int(str(pin_name))
	var origin_column: int = chip.state.get("dip_origin_column", 0)
	if pin_number >= 1 and pin_number <= 7:
		return {"column": origin_column + pin_number - 1, "row": 5}
	if pin_number >= 8 and pin_number <= 14:
		return {"column": origin_column + 14 - pin_number, "row": 4}
	return {}


func _pin_position(chip, pin_name: StringName) -> Vector2:
	var pin_holes: Dictionary = chip.state.get("pin_holes", {})
	if pin_holes.has(str(pin_name)):
		var hole: Dictionary = pin_holes[str(pin_name)]
		return _breadboard_hole_screen_position(int(hole.get("column", 0)), int(hole.get("row", 0)))

	if _is_breadboard_dip(chip):
		return _breadboard_dip_pin_position(chip, pin_name)

	var rect: Rect2 = _chip_rect(chip)
	return _pin_position_for_definition(chip.definition, rect, pin_name)


func _has_any_pin_hole(chip) -> bool:
	var pin_holes: Dictionary = chip.state.get("pin_holes", {})
	return not pin_holes.is_empty()


func _is_breadboard_dip(chip) -> bool:
	return chip.state.has("dip_origin_column")


func _is_spanning_resistor(chip) -> bool:
	if chip.definition.id not in [&"resistor_2k2", &"resistor_220"]:
		return false

	var pin_holes: Dictionary = chip.state.get("pin_holes", {})
	return pin_holes.has("A") and pin_holes.has("B")


func _spanning_resistor_rect(chip) -> Rect2:
	var pin_a := _pin_position(chip, &"A")
	var pin_b := _pin_position(chip, &"B")
	var left := minf(pin_a.x, pin_b.x)
	var right := maxf(pin_a.x, pin_b.x)
	var center_y := (pin_a.y + pin_b.y) * 0.5
	return Rect2(Vector2(left, center_y - 15.0 * zoom), Vector2(maxf(1.0, right - left), 30.0 * zoom))


func _is_spanning_switch(chip) -> bool:
	if chip.definition.id != &"switch":
		return false

	var pin_holes: Dictionary = chip.state.get("pin_holes", {})
	return pin_holes.has("A") and pin_holes.has("B")


# A pushbutton straddles the centre groove: pin A on the top strip, pin B on the
# bottom strip. The body is a square cap centred between the two legs.
func _spanning_switch_rect(chip) -> Rect2:
	var pin_a := _pin_position(chip, &"A")
	var pin_b := _pin_position(chip, &"B")
	var center := (pin_a + pin_b) * 0.5
	var size := Vector2(44.0, 44.0) * zoom
	return Rect2(center - size * 0.5, size)


func _breadboard_hole_screen_position(column: int, row_index: int) -> Vector2:
	return _bb830_hole_position(_grid_rect_to_screen(BOARD_GRID_RECT), column, row_index)


func _breadboard_dip_pin_position(chip, pin_name: StringName) -> Vector2:
	var pin_number := int(str(pin_name))
	var origin_column: int = chip.state.get("dip_origin_column", 0)
	var column := origin_column
	var row_index := 5

	if pin_number >= 1 and pin_number <= 7:
		column = origin_column + pin_number - 1
		row_index = 5
	elif pin_number >= 8 and pin_number <= 14:
		column = origin_column + 14 - pin_number
		row_index = 4

	return _breadboard_hole_screen_position(column, row_index)


func _breadboard_dip_rect(chip) -> Rect2:
	var pin_14 := _breadboard_dip_pin_position(chip, &"14")
	var pin_7 := _breadboard_dip_pin_position(chip, &"7")
	var center := (pin_14 + pin_7) * 0.5
	var visual_size := DIP_VISUAL_SIZE * zoom
	return Rect2(center - visual_size * 0.5, visual_size)


func _anchored_chip_rect(chip) -> Rect2:
	var first_pin_name: StringName = chip.definition.pins[0].get("name")
	var pin_position := _pin_position(chip, first_pin_name)
	var component_size := _component_size(chip) * zoom
	match chip.definition.id:
		&"power_5v", &"ground", &"toggle":
			return Rect2(pin_position - Vector2(component_size.x - 3.0 * zoom, component_size.y * 0.5), component_size)
		&"led":
			return Rect2(pin_position - Vector2(8.0 * zoom, component_size.y * 0.34), component_size)
	return Rect2(pin_position - component_size * 0.5, component_size)


func _pin_position_for_definition(definition, rect: Rect2, pin_name: StringName) -> Vector2:
	var pin: Dictionary = definition.get_pin(pin_name)
	var same_side_count := 0
	var same_side_index := 0
	var side: StringName = pin.get("side", &"left")

	for definition_pin: Dictionary in definition.pins:
		if definition_pin.get("side") == side:
			if definition_pin.get("name") == pin_name:
				same_side_index = same_side_count
			same_side_count += 1

	var t := float(same_side_index + 1) / float(same_side_count + 1)
	match side:
		&"right":
			return Vector2(rect.end.x, rect.position.y + rect.size.y * t)
		&"top":
			return Vector2(rect.position.x + rect.size.x * t, rect.position.y)
		&"bottom":
			return Vector2(rect.position.x + rect.size.x * t, rect.end.y)
		_:
			return Vector2(rect.position.x, rect.position.y + rect.size.y * t)


func _wire_color_for_net(net) -> Color:
	match net.label:
		"VCC":
			return Color(0.86, 0.08, 0.06)
		"GND":
			return Color(0.02, 0.02, 0.018)
		"A":
			return Color(0.03, 0.28, 0.76)
		"B":
			return Color(0.02, 0.20, 0.56)
		"Cin":
			return Color(0.88, 0.88, 0.82)
		"SUM":
			return Color(0.88, 0.07, 0.05)
		"Cout":
			return Color(0.07, 0.58, 0.16)
		"Y":
			return Color(0.88, 0.07, 0.05)
		"CARRY":
			return Color(0.07, 0.58, 0.16)
		"A xor B", "A and B", "(A xor B) and Cin":
			return Color(0.95, 0.70, 0.08)
	return WIRE_COLORS[net.id % WIRE_COLORS.size()]


func _should_label_net(net_label: String) -> bool:
	return net_label in ["VCC", "GND", "A", "B", "Cin", "Y", "SUM", "CARRY", "Cout"]


func _grid_rect_to_screen(grid_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(grid_rect.position * GRID_SPACING), grid_rect.size * GRID_SPACING * zoom)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position * zoom + pan + size * 0.5


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - size * 0.5 - pan) / zoom


func _inset_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position + Vector2(amount, amount), rect.size - Vector2(amount * 2.0, amount * 2.0))


func _offset_rect(rect: Rect2, offset: Vector2) -> Rect2:
	return Rect2(rect.position + offset, rect.size)


func _draw_chip_shadow(rect: Rect2) -> void:
	_draw_rounded_rect(_offset_rect(rect, Vector2(0.0, 5.0 * zoom)), Color(0.08, 0.07, 0.05, 0.28), Color.TRANSPARENT, 0.0, 9.0 * zoom)


func _draw_rounded_rect(rect: Rect2, fill: Color, border: Color, border_width: float, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(round(border_width)))
	style.set_corner_radius_all(int(round(radius)))
	draw_style_box(style, rect)


func _draw_centered_text(font: Font, rect: Rect2, text: String, font_size: int, color: Color) -> void:
	var baseline := rect.position.y + rect.size.y * 0.5 + font_size * 0.36
	draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)
