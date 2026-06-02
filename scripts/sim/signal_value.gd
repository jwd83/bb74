class_name SignalValue
extends RefCounted

enum State { LOW, HIGH, Z, X }

static func resolve(drivers: Array) -> int:
	if drivers.is_empty():
		return State.Z

	var saw_low := false
	var saw_high := false

	for value: int in drivers:
		if value == State.X:
			return State.X
		if value == State.LOW:
			saw_low = true
		elif value == State.HIGH:
			saw_high = true

	if saw_low and saw_high:
		return State.X
	if saw_high:
		return State.HIGH
	if saw_low:
		return State.LOW
	return State.Z


static func label(value: int) -> String:
	match value:
		State.LOW:
			return "0"
		State.HIGH:
			return "1"
		State.Z:
			return "Z"
		State.X:
			return "X"
		_:
			return "?"


static func color(value: int) -> Color:
	match value:
		State.LOW:
			return Color(0.24, 0.45, 0.72)
		State.HIGH:
			return Color(1.0, 0.82, 0.24)
		State.Z:
			return Color(0.45, 0.48, 0.52)
		State.X:
			return Color(0.95, 0.22, 0.18)
		_:
			return Color.WHITE
