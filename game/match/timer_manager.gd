class_name MatchTimerManager
extends RefCounted

var seconds_remaining: float = 99.0

func reset(seconds: int) -> void:
	seconds_remaining = float(seconds)

func tick(delta: float) -> bool:
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	return seconds_remaining <= 0.0

