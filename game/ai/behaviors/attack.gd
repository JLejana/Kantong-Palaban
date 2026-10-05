class_name AIAttackBehavior
extends RefCounted

func score(distance: float) -> float:
	return 1.0 if distance < 150.0 else 0.0

