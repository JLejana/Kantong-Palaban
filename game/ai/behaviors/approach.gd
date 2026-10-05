class_name AIApproachBehavior
extends RefCounted

func score(distance: float) -> float:
	return clampf(distance / 300.0, 0.0, 1.0)

