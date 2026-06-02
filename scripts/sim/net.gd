class_name Net
extends RefCounted

const SignalValue = preload("res://scripts/sim/signal_value.gd")

var id: int
var label: String
var value: int = SignalValue.State.Z
var connections: Array[Dictionary] = []
var drivers: Array[int] = []
# Weak drivers model pull resistors: they only set the level when nothing strong
# (a supply, a gate, or a closed switch) is driving the net.
var weak_drivers: Array[int] = []


func _init(net_id: int = 0, net_label: String = "") -> void:
	id = net_id
	label = net_label


func reset_drivers() -> void:
	drivers.clear()
	weak_drivers.clear()
