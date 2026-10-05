class_name MobilePlatform
extends RefCounted

static func is_active() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

