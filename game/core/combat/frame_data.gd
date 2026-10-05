class_name FrameData
extends RefCounted

var simulation_frame: int = 0
var attack_frame: int = -1

func advance() -> void:
	simulation_frame += 1
	if attack_frame >= 0:
		attack_frame += 1

