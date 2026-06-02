class_name Net
extends RefCounted

const SignalValue = preload("res://scripts/sim/signal_value.gd")

var id: int
var label: String
var value: int = SignalValue.State.Z
var connections: Array[Dictionary] = []
var drivers: Array[int] = []


func _init(net_id: int = 0, net_label: String = "") -> void:
	id = net_id
	label = net_label


func reset_drivers() -> void:
	drivers.clear()
