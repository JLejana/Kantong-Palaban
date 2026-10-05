class_name NetworkDebug
extends Label

var ping_ms: int = -1

func _process(_delta: float) -> void:
	text = "Ping: --" if ping_ms < 0 else "Ping: %d ms" % ping_ms

