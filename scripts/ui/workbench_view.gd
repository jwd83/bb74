class_name WorkbenchView
extends Control

const SignalValue = preload("res://scripts/sim/signal_value.gd")

signal circuit_interacted

const CHIP_SIZE := Vector2(124.0, 70.0)
const GRID_SPACING := 20.0
const BOARD_GRID_RECT := Rect2(Vector2(-29.5, -9.0), Vector2(59.0, 18.0))
const DEFAULT_PAN := Vector2(0.0, -72.0)
const WIRE_COLORS := [
	Color(0.92, 0.09, 0.08),
	Color(0.04, 0.34, 0.86),
	Color(0.96, 0.76, 0.07),
	Color(0.06, 0.58, 0.20),
	Color(0.05, 0.05, 0.05),
	Color(0.88, 0.88, 0.84),
]

var circuit
var pan := DEFAULT_PAN
var zoom := 1.0

var _is_panning := false
var _last_mouse_position := Vector2.ZERO
var _hovered_net_id := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_circuit(next_circuit) -> void:
	if circuit and circuit.changed.is_connected(queue_redraw):
		circuit.changed.disconnect(queue_redraw)

	circuit = next_circuit
	_hovered_net_id = -1
	if circuit:
		circuit.changed.connect(queue_redraw)
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
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.08)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.08)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_panning = event.pressed
		_last_mouse_position = event.position
	elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var chip = _chip_at(event.position)
		if chip and chip.definition.id == &"toggle":
			chip.state["on"] = not chip.state.get("on", false)
			circuit.settle()
			circuit_interacted.emit()
			queue_redraw()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_panning:
		_set_hovered_net(_hover_net_at(event.position))
		return

	pan += event.position - _last_mouse_position
	_last_mouse_position = event.position
	_set_hovered_net(-1)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hovered_net(-1)


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_position)
	zoom = clampf(zoom * factor, 0.35, 2.75)
	var after := _screen_to_world(screen_position)
	pan += (after - before) * zoom
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.73, 0.70), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 96.0)), Color(0.86, 0.84, 0.73, 0.26), true)
	_draw_grid()
	_draw_breadboard()

	if not circuit:
		return

	for net in circuit.nets:
		if net.id != _hovered_net_id:
			_draw_net(net)
	for net in circuit.nets:
		if net.id == _hovered_net_id:
			_draw_net(net)
			break
	for chip in circuit.chips:
		_draw_chip(chip)


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
	var x_left := board_rect.position.x + 28.0 * zoom
	var x_right := board_rect.end.x - 38.0 * zoom

	draw_string(font, board_rect.position + Vector2(20.0, 35.0) * zoom, "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(16, int(24 * zoom)), red)
	draw_string(font, board_rect.position + Vector2(20.0, 82.0) * zoom, "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(14, int(21 * zoom)), dark)
	draw_string(font, board_rect.position + Vector2(20.0, board_rect.size.y - 78.0 * zoom), "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(16, int(24 * zoom)), red)
	draw_string(font, board_rect.position + Vector2(20.0, board_rect.size.y - 30.0 * zoom), "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(14, int(21 * zoom)), dark)
	draw_string(font, board_rect.position + Vector2(18.0, board_rect.size.y * 0.52), "BB830", HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(10, int(15 * zoom)), dark)

	for index: int in range(row_letters.size()):
		var row_y := _bb830_row_y(board_rect, index)
		draw_string(font, Vector2(x_left, row_y + 4.0 * zoom), row_letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(8, int(10 * zoom)), dark)
		draw_string(font, Vector2(x_right, row_y + 4.0 * zoom), row_letters[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(8, int(10 * zoom)), dark)

	var numbers := [60, 55, 50, 45, 40, 35, 30, 25, 20]
	for index: int in range(numbers.size()):
		var x := board_rect.position.x + (120.0 + index * 112.0) * zoom
		var label := str(numbers[index])
		draw_string(font, Vector2(x, board_rect.position.y + 138.0 * zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 30.0 * zoom, max(10, int(16 * zoom)), dark)
		draw_string(font, Vector2(x, board_rect.end.y - 92.0 * zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 30.0 * zoom, max(10, int(16 * zoom)), dark)


func _draw_bb830_rails(board_rect: Rect2) -> void:
	var rail_left := board_rect.position.x + 68.0 * zoom
	var rail_right := board_rect.end.x - 48.0 * zoom
	var rail_width := maxf(1.6, 2.3 * zoom)
	var red := Color(0.75, 0.09, 0.07, 0.85)
	var black := Color(0.06, 0.06, 0.055, 0.92)

	var rail_ys := [
		board_rect.position.y + 34.0 * zoom,
		board_rect.position.y + 80.0 * zoom,
		board_rect.end.y - 80.0 * zoom,
		board_rect.end.y - 34.0 * zoom,
	]
	var rail_colors := [red, black, red, black]

	for index: int in range(rail_ys.size()):
		draw_line(Vector2(rail_left, rail_ys[index]), Vector2(rail_right, rail_ys[index]), rail_colors[index], rail_width, true)
		_draw_rail_holes(rail_left, rail_right, rail_ys[index], rail_colors[index])


func _draw_bb830_terminal_strips(board_rect: Rect2) -> void:
	var columns := 52
	var hole_gap := (board_rect.size.x - 176.0 * zoom) / float(columns - 1)
	var start_x := board_rect.position.x + 92.0 * zoom

	for column: int in range(columns):
		var x := start_x + hole_gap * column
		for row: int in range(5):
			_draw_breadboard_hole(Vector2(x, _bb830_row_y(board_rect, row)))
			_draw_breadboard_hole(Vector2(x, _bb830_row_y(board_rect, row + 5)))

	var groove_y := board_rect.position.y + board_rect.size.y * 0.5
	draw_line(
		Vector2(board_rect.position.x + 72.0 * zoom, groove_y),
		Vector2(board_rect.end.x - 50.0 * zoom, groove_y),
		Color(0.55, 0.55, 0.50, 0.45),
		maxf(2.0, 5.0 * zoom),
		true
	)
	draw_line(
		Vector2(board_rect.position.x + 72.0 * zoom, groove_y),
		Vector2(board_rect.end.x - 50.0 * zoom, groove_y),
		Color(0.98, 0.98, 0.94, 0.68),
		maxf(1.0, 1.2 * zoom),
		true
	)


func _draw_rail_holes(left: float, right: float, y: float, accent: Color) -> void:
	var count := 41
	var gap := (right - left) / float(count - 1)
	for index: int in range(count):
		_draw_breadboard_hole(Vector2(left + gap * index, y), accent)


func _draw_breadboard_hole(position: Vector2, accent: Color = Color(0.53, 0.53, 0.49)) -> void:
	var outer := Rect2(position - Vector2(4.0, 4.0) * zoom, Vector2(8.0, 8.0) * zoom)
	var inner := Rect2(position - Vector2(2.4, 2.4) * zoom, Vector2(4.8, 4.8) * zoom)
	_draw_rounded_rect(outer, Color(0.82, 0.82, 0.78), accent.darkened(0.18), 0.6 * zoom, 1.7 * zoom)
	_draw_rounded_rect(inner, Color(0.07, 0.065, 0.055), Color(0.02, 0.02, 0.018), 0.0, 1.0 * zoom)


func _bb830_row_y(board_rect: Rect2, row_index: int) -> float:
	var top_rows_start := board_rect.position.y + 126.0 * zoom
	var bottom_rows_start := board_rect.position.y + 228.0 * zoom
	var row_gap := 20.0 * zoom
	if row_index < 5:
		return top_rows_start + row_gap * row_index
	return bottom_rows_start + row_gap * (row_index - 5)


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


func _draw_net(net) -> void:
	if net.connections.size() < 2:
		return

	var connections: Array[Dictionary] = _net_connections(net)
	var highlighted: bool = net.id == _hovered_net_id
	var color := _wire_color_for_net(net)
	if highlighted:
		color = color.lightened(0.22)
	var line_width: float = maxf(2.8, 4.2 * zoom) * (1.45 if highlighted else 1.0)
	if _is_power_net(net.label):
		_draw_power_net(net.label, connections, color, line_width, highlighted)
	elif _uses_breadboard_bus(net.label, connections):
		_draw_bus_net(net.label, connections, color, line_width, highlighted)
	else:
		var points: Array[Vector2] = []
		for connection: Dictionary in connections:
			points.append(connection["position"])

		var wire_count: int = points.size() - 1
		for index in range(1, points.size()):
			_draw_wire(points[0], points[index], color, line_width, net.label, index, wire_count, highlighted)

	if highlighted or (_should_label_net(net.label) and zoom >= 1.18):
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


func _draw_bus_net(net_label: String, connections: Array[Dictionary], color: Color, line_width: float, highlighted: bool) -> void:
	var driver := _first_driver_connection(connections)
	var loads: Array[Dictionary] = []
	for connection: Dictionary in connections:
		if connection != driver:
			loads.append(connection)

	var bus_points := _breadboard_bus_points(net_label, loads.size())
	if bus_points.is_empty():
		return

	_draw_bus_tie_strip(net_label, bus_points, color, highlighted)
	_draw_wire(driver["position"], bus_points[0], color, line_width, net_label, 1, 1, highlighted)

	for index: int in range(loads.size()):
		var bus_index: int = mini(index + 1, bus_points.size() - 1)
		_draw_wire(bus_points[bus_index], loads[index]["position"], color, line_width, net_label, index + 1, loads.size(), highlighted)


func _draw_bus_tie_strip(net_label: String, bus_points: Array[Vector2], color: Color, highlighted: bool) -> void:
	if bus_points.is_empty():
		return

	var strip_rect := _bus_tie_rect(bus_points)
	if highlighted:
		_draw_rounded_rect(_expanded_rect(strip_rect, 4.0 * zoom), Color(color.r, color.g, color.b, 0.22), Color(color.r, color.g, color.b, 0.38), 1.0 * zoom, 6.0 * zoom)
	_draw_rounded_rect(strip_rect, Color(color.r, color.g, color.b, 0.28 if highlighted else 0.18), Color(color.r, color.g, color.b, 0.85 if highlighted else 0.55), (2.0 if highlighted else 1.0) * zoom, 4.0 * zoom)

	for point: Vector2 in bus_points:
		draw_circle(point, (7.0 if highlighted else 5.2) * zoom, Color(color.r, color.g, color.b, 0.46 if highlighted else 0.36))
		draw_circle(point, (3.3 if highlighted else 2.6) * zoom, color.lightened(0.28))

	var font := get_theme_default_font()
	var label := _short_bus_label(net_label)
	var label_rect := Rect2(
		Vector2(strip_rect.position.x - 22.0 * zoom, strip_rect.position.y - 13.0 * zoom),
		Vector2(58.0, 11.0) * zoom
	)
	draw_string(font, label_rect.position + Vector2(0.0, label_rect.size.y), label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, max(8, int(9 * zoom)), color.darkened(0.35))


func _draw_power_net(net_label: String, connections: Array[Dictionary], color: Color, line_width: float, highlighted: bool) -> void:
	var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
	var rail_points: Array[Vector2] = []

	for index: int in range(connections.size()):
		var connection: Dictionary = connections[index]
		var pin_position: Vector2 = connection["position"]
		var rail_point := _power_rail_point(board_rect, net_label, pin_position, index)
		rail_points.append(rail_point)
		_draw_wire(rail_point, pin_position, color, line_width, net_label, 1, 1, highlighted)
		_draw_power_landing(net_label, rail_point, color, highlighted)

	_draw_power_rail_label(board_rect, net_label, color, highlighted)


func _draw_power_landing(net_label: String, rail_point: Vector2, color: Color, highlighted: bool) -> void:
	var radius := (7.0 if highlighted else 5.2) * zoom
	draw_circle(rail_point, radius + 2.0 * zoom, Color(color.r, color.g, color.b, 0.18 if not highlighted else 0.32))
	draw_circle(rail_point, radius, color)
	draw_circle(rail_point, radius, Color(0.03, 0.03, 0.025), false, maxf(1.0, 1.2 * zoom))
	if highlighted:
		draw_circle(rail_point, radius + 5.0 * zoom, Color(color.r, color.g, color.b, 0.18), false, maxf(1.0, 2.0 * zoom))


func _draw_power_rail_label(board_rect: Rect2, net_label: String, color: Color, highlighted: bool) -> void:
	var font := get_theme_default_font()
	var y := board_rect.position.y + (34.0 if net_label == "VCC" else board_rect.size.y - 34.0) * zoom
	var rect := Rect2(board_rect.position + Vector2(50.0, (34.0 if net_label == "VCC" else board_rect.size.y - 45.0)) * zoom, Vector2(52.0, 18.0) * zoom)
	_draw_rounded_rect(rect, Color(color.r, color.g, color.b, 0.20 if not highlighted else 0.34), Color(color.r, color.g, color.b, 0.72), 1.0 * zoom, 4.0 * zoom)
	draw_string(font, Vector2(rect.position.x, y + 5.0 * zoom), net_label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, max(8, int(10 * zoom)), color.lightened(0.50 if net_label == "GND" else 0.25))


func _net_connections(net) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	for connection: Dictionary in net.connections:
		var chip = connection.get("chip")
		var pin_name: StringName = connection.get("pin")
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
	var connections: Array[Dictionary] = _net_connections(net)
	var best_distance := 1000000.0

	if _is_power_net(net.label):
		var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
		for index: int in range(connections.size()):
			var pin_position: Vector2 = connections[index]["position"]
			var rail_point := _power_rail_point(board_rect, net.label, pin_position, index)
			best_distance = minf(best_distance, rail_point.distance_to(screen_position))
			best_distance = minf(
			best_distance,
			_distance_to_polyline(screen_position, _wire_curve_points(rail_point, pin_position, net.label, 1, 1))
		)
		return best_distance

	if _uses_breadboard_bus(net.label, connections):
		var driver := _first_driver_connection(connections)
		var loads: Array[Dictionary] = []
		for connection: Dictionary in connections:
			if connection != driver:
				loads.append(connection)

		var bus_points := _breadboard_bus_points(net.label, loads.size())
		if bus_points.is_empty():
			return best_distance

		best_distance = minf(best_distance, _distance_to_rect(screen_position, _expanded_rect(_bus_tie_rect(bus_points), 5.0 * zoom)))
		best_distance = minf(
			best_distance,
			_distance_to_polyline(screen_position, _wire_curve_points(driver["position"], bus_points[0], net.label, 1, 1))
		)

		for index: int in range(loads.size()):
			var bus_index: int = mini(index + 1, bus_points.size() - 1)
			best_distance = minf(
				best_distance,
				_distance_to_polyline(
					screen_position,
					_wire_curve_points(bus_points[bus_index], loads[index]["position"], net.label, index + 1, loads.size())
				)
			)
		return best_distance

	var points: Array[Vector2] = []
	for connection: Dictionary in connections:
		points.append(connection["position"])

	var wire_count: int = points.size() - 1
	for index: int in range(1, points.size()):
		best_distance = minf(
			best_distance,
			_distance_to_polyline(screen_position, _wire_curve_points(points[0], points[index], net.label, index, wire_count))
		)

	return best_distance


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


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	if rect.has_point(point):
		return 0.0

	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()


func _bus_tie_rect(bus_points: Array[Vector2]) -> Rect2:
	var min_x := bus_points[0].x
	var max_x := bus_points[0].x
	var min_y := bus_points[0].y
	var max_y := bus_points[0].y
	for point: Vector2 in bus_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	return Rect2(
		Vector2(min_x - 7.0 * zoom, min_y - 7.0 * zoom),
		Vector2(max_x - min_x + 14.0 * zoom, max_y - min_y + 14.0 * zoom)
	)


func _expanded_rect(rect: Rect2, amount: float) -> Rect2:
	return Rect2(rect.position - Vector2(amount, amount), rect.size + Vector2(amount * 2.0, amount * 2.0))


func _uses_breadboard_bus(net_label: String, connections: Array[Dictionary]) -> bool:
	if not _has_bus_layout(net_label):
		return false

	var output_count := 0
	var load_count := 0
	for connection: Dictionary in connections:
		if connection["direction"] == &"out":
			output_count += 1
		else:
			load_count += 1

	return output_count == 1 and load_count > 1


func _first_driver_connection(connections: Array[Dictionary]) -> Dictionary:
	for connection: Dictionary in connections:
		if connection["direction"] == &"out":
			return connection
	return connections[0]


func _breadboard_bus_points(net_label: String, needed_slots: int) -> Array[Vector2]:
	var layout := _bus_layout(net_label)
	if layout.is_empty():
		return []

	var board_rect := _grid_rect_to_screen(BOARD_GRID_RECT)
	var points: Array[Vector2] = []
	var column: int = layout["column"]
	var rows: Array = layout["rows"]
	var slots: int = mini(needed_slots + 1, rows.size())

	for index: int in range(slots):
		points.append(_bb830_hole_position(board_rect, column, int(rows[index])))

	return points


func _bus_layout(net_label: String) -> Dictionary:
	match net_label:
		"A":
			return {"column": 7, "rows": [0, 1, 2, 3, 4]}
		"B":
			return {"column": 11, "rows": [0, 1, 2, 3, 4]}
		"Cin":
			return {"column": 3, "rows": [0, 1, 2, 3, 4]}
		"A xor B":
			return {"column": 26, "rows": [0, 1, 2, 3, 4]}
		"SUM":
			return {"column": 45, "rows": [5, 6, 7, 8, 9]}
		"Cout":
			return {"column": 45, "rows": [0, 1, 2, 3, 4]}
	return {}


func _has_bus_layout(net_label: String) -> bool:
	return not _bus_layout(net_label).is_empty()


func _bb830_hole_position(board_rect: Rect2, column: int, row_index: int) -> Vector2:
	var columns := 52
	var hole_gap := (board_rect.size.x - 176.0 * zoom) / float(columns - 1)
	var start_x := board_rect.position.x + 92.0 * zoom
	return Vector2(start_x + hole_gap * column, _bb830_row_y(board_rect, row_index))


func _power_rail_point(board_rect: Rect2, net_label: String, pin_position: Vector2, slot_index: int) -> Vector2:
	var rail_left := board_rect.position.x + 68.0 * zoom
	var rail_right := board_rect.end.x - 48.0 * zoom
	var rail_y := board_rect.position.y + 34.0 * zoom

	if net_label == "GND":
		rail_y = board_rect.position.y + 80.0 * zoom if pin_position.y < board_rect.position.y + board_rect.size.y * 0.5 else board_rect.end.y - 34.0 * zoom
	elif pin_position.y > board_rect.position.y + board_rect.size.y * 0.5:
		rail_y = board_rect.end.y - 80.0 * zoom

	var x := clampf(pin_position.x + float((slot_index % 3) - 1) * 8.0 * zoom, rail_left, rail_right)
	return Vector2(x, rail_y)


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


func _short_bus_label(net_label: String) -> String:
	match net_label:
		"A xor B":
			return "A^B"
		"(A xor B) and Cin":
			return "(A^B)&Cin"
	return net_label


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
		&"toggle":
			_draw_toggle(chip, rect)
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
	if zoom >= 1.25 and not [&"resistor_2k2", &"resistor_220", &"led", &"toggle"].has(chip.definition.id):
		draw_string(font, position + label_offset, str(pin_name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.10, 0.11, 0.10))


func _chip_rect(chip) -> Rect2:
	var top_left := _world_to_screen(Vector2(chip.position) * GRID_SPACING)
	return Rect2(top_left, _component_size(chip) * zoom)


func _component_size(chip) -> Vector2:
	match chip.definition.id:
		&"toggle":
			return Vector2(58.0, 48.0)
		&"led":
			return Vector2(68.0, 82.0)
		&"resistor_2k2", &"resistor_220":
			return Vector2(94.0, 30.0)
		&"ic_7486", &"ic_7408", &"ic_7432":
			return Vector2(160.0, 88.0)
		_:
			return CHIP_SIZE


func _chip_at(screen_position: Vector2):
	if not circuit:
		return null

	for chip in circuit.chips:
		if _chip_rect(chip).has_point(screen_position):
			return chip
	return null


func _pin_position(chip, pin_name: StringName) -> Vector2:
	var rect: Rect2 = _chip_rect(chip)
	var pin: Dictionary = chip.definition.get_pin(pin_name)
	var same_side_count := 0
	var same_side_index := 0
	var side: StringName = pin.get("side", &"left")

	for definition_pin: Dictionary in chip.definition.pins:
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
		"A xor B", "A and B", "(A xor B) and Cin":
			return Color(0.95, 0.70, 0.08)
	return WIRE_COLORS[net.id % WIRE_COLORS.size()]


func _should_label_net(net_label: String) -> bool:
	return net_label in ["VCC", "GND", "A", "B", "Cin", "SUM", "Cout"]


func _is_power_net(net_label: String) -> bool:
	return net_label in ["VCC", "GND"]


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
