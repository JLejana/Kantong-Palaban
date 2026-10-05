class_name AIDefendBehavior
extends RefCounted

func score(opponent_is_attacking: bool) -> float:
	return 0.8 if opponent_is_attacking else 0.1

