class_name DesktopPlatform
extends RefCounted

static func is_active() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web")

