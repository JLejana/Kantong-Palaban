class_name WebPlatform
extends RefCounted

static func is_active() -> bool:
	return OS.has_feature("web")

