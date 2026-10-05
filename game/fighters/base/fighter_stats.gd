class_name FighterStats
extends Resource

@export var display_name: String = "Fighter"
@export var max_health: int = 100
@export var walk_speed: float = 260.0
@export var backward_walk_speed: float = 190.0
@export var jump_force: float = 620.0
@export var gravity: float = 1750.0
@export var weight: float = 1.0
@export_range(0.5, 2.0, 0.05) var damage_scale: float = 1.0
@export var attacks: Array[AttackData] = []
@export var portrait: Texture2D
@export var voice_set: Resource
@export var special_move_data: Array[Resource] = []
@export var body_color: Color = Color("36a9e1")
@export var accent_color: Color = Color("ffd447")
@export var skin_color: Color = Color("f1c27d")
@export_enum("swift", "power") var silhouette_style: String = "swift"
@export var animation_sheets: Dictionary = {}
@export var animation_fps: Dictionary = {}
@export var held_animation_ranges: Dictionary = {}
@export var sprite_scale: Vector2 = Vector2(0.25, 0.25)
@export var sprite_offset: Vector2 = Vector2(0.0, -56.0)
@export var sprite_faces_right: bool = true

func find_attack(attack_id: StringName) -> AttackData:
	for attack in attacks:
		if attack != null and attack.id == attack_id:
			return attack
	return null

func build_sprite_frames() -> SpriteFrames:
	if animation_sheets.is_empty():
		return null
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for key: Variant in animation_sheets:
		var animation := StringName(str(key))
		var texture := animation_sheets[key] as Texture2D
		if texture == null or texture.get_width() % 4 != 0 or texture.get_height() % 2 != 0:
			continue
		result.add_animation(animation)
		result.set_animation_speed(animation, float(animation_fps.get(str(key), 8.0)))
		result.set_animation_loop(animation, animation in [&"idle", &"walk_forward", &"walk_backward"])
		var frame_width := texture.get_width() / 4
		var frame_height := texture.get_height() / 2
		var held_range: Vector4i = held_animation_ranges.get(str(key), Vector4i.ZERO)
		if held_range != Vector4i.ZERO:
			for frame_index in range(held_range.x, held_range.x + held_range.y):
				_add_sheet_frame(result, animation, texture, frame_index, frame_width, frame_height)
			var held_animation := StringName("%s_hold" % animation)
			result.add_animation(held_animation)
			result.set_animation_speed(held_animation, float(animation_fps.get(str(key), 8.0)))
			result.set_animation_loop(held_animation, true)
			for frame_index in range(held_range.z, held_range.z + held_range.w):
				_add_sheet_frame(result, held_animation, texture, frame_index, frame_width, frame_height)
		else:
			for frame_index in range(8):
				_add_sheet_frame(result, animation, texture, frame_index, frame_width, frame_height)
	return result if result.get_animation_names().size() > 0 else null

func _add_sheet_frame(frames: SpriteFrames, animation: StringName, texture: Texture2D, frame_index: int, frame_width: int, frame_height: int) -> void:
	if frame_index < 0 or frame_index >= 8:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2((frame_index % 4) * frame_width, (frame_index / 4) * frame_height, frame_width, frame_height)
	frames.add_frame(animation, atlas)

