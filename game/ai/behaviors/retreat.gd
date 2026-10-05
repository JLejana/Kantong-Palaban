class_name AIRetreatBehavior
extends RefCounted

func score(distance: float) -> float:
	return 0.7 if distance < 70.0 else 0.0

