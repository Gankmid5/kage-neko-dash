extends CharacterBody2D
class_name CatNinjaPlayer
## Crisp Geometry-Dash-inspired 2D Cat Ninja runner with Line2D scarf, smooth silhouette, and katana slash.

signal died(reason: String)
signal slashed_something(world_pos: Vector2, is_bullet: bool)

const GRAVITY := 2970.0
const JUMP_VEL := -812.0
const DOUBLE_JUMP_VEL := -730.0
const FAST_FALL_ACCEL := 4800.0
const SLASH_DURATION := 0.16
const SLASH_COOLDOWN := 0.16

var run_speed: float = 430.0
var dead: bool = false
var active: bool = false

var _air_jumps: int = 1
var _coyote_timer: float = 0.0
var _jump_buffer: float = 0.0
var slash_timer: float = 0.0
var _slash_cd: float = 0.0
var _flip_angle: float = 0.0
var _flipping: bool = false
var _scale_x: float = 1.0
var _scale_y: float = 1.0
var _was_grounded: bool = false
var _time: float = 0.0
var _ghost_timer: float = 0.0

var _scarf: Array[Vector2] = []
var _scarf_line: Line2D
var _afterimages: Array[Dictionary] = []
var _slash_area: Area2D
var _slash_shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 34)
	col.shape = rect
	col.position = Vector2(0, -17)
	add_child(col)

	# Smooth tapered Line2D for the flowing crimson scarf
	_scarf_line = Line2D.new()
	_scarf_line.top_level = true
	_scarf_line.width = 8.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.15))
	_scarf_line.width_curve = curve
	_scarf_line.default_color = Color(1.15, 0.25, 0.30) # Slight HDR for subtle glow
	_scarf_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_scarf_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_scarf_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_scarf_line.antialiased = true
	add_child(_scarf_line)

	_slash_area = Area2D.new()
	_slash_area.collision_layer = 0
	_slash_area.collision_mask = 4 | 8
	_slash_area.monitoring = false
	_slash_shape = CollisionShape2D.new()
	var slash_rect := RectangleShape2D.new()
	slash_rect.size = Vector2(118, 92)
	_slash_shape.shape = slash_rect
	_slash_shape.position = Vector2(52, -18)
	_slash_area.add_child(_slash_shape)
	add_child(_slash_area)

	_slash_area.area_entered.connect(_on_slash_area_entered)
	_reset_scarf()

func _reset_scarf() -> void:
	_scarf.clear()
	for i in 10:
		_scarf.append(global_position + Vector2(-i * 6, -24))
	if _scarf_line:
		_scarf_line.points = PackedVector2Array(_scarf)

func reset_at(pos: Vector2, speed: float) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	run_speed = speed
	dead = false
	active = true
	_air_jumps = 1
	_coyote_timer = 0.0
	_jump_buffer = 0.0
	slash_timer = 0.0
	_slash_cd = 0.0
	_flip_angle = 0.0
	_flipping = false
	_scale_x = 1.0
	_scale_y = 1.0
	_was_grounded = false
	_afterimages.clear()
	_slash_area.monitoring = false
	_scarf_line.visible = true
	_reset_scarf()
	queue_redraw()

func pad_launch() -> void:
	velocity.y = -1020.0
	_air_jumps = 1
	_flipping = true
	_flip_angle = 0.0
	_scale_x = 0.74
	_scale_y = 1.32
	SoundFX.play_boost()

func orb_boost() -> void:
	velocity.y = -820.0
	_air_jumps = 1
	_flipping = true
	_flip_angle = 0.0
	_scale_x = 0.78
	_scale_y = 1.25
	SoundFX.play_boost()

func _physics_process(delta: float) -> void:
	_time += delta
	for i in range(_afterimages.size() - 1, -1, -1):
		_afterimages[i]["alpha"] -= delta * 6.0
		if _afterimages[i]["alpha"] <= 0.0:
			_afterimages.remove_at(i)

	if not active or dead:
		_scarf_line.visible = not dead and active
		queue_redraw()
		return

	_scarf_line.visible = true
	velocity.x = run_speed

	_ghost_timer -= delta
	if (not is_on_floor() or slash_timer > 0.0) and _ghost_timer <= 0.0:
		_ghost_timer = 0.045
		_afterimages.append({"pos": global_position, "alpha": 0.55})

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	if is_on_floor():
		_coyote_timer = 0.09
		_air_jumps = 1
		_flipping = false
		_flip_angle = 0.0
		if not _was_grounded:
			_scale_x = 1.24
			_scale_y = 0.78
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_was_grounded = is_on_floor()

	velocity.y += GRAVITY * delta
	if Input.is_action_pressed("fast_fall") and not is_on_floor():
		velocity.y += FAST_FALL_ACCEL * delta

	if _jump_buffer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = JUMP_VEL
			_coyote_timer = 0.0
			_jump_buffer = 0.0
			_scale_x = 0.76
			_scale_y = 1.28
			SoundFX.play_jump()
		elif _air_jumps > 0:
			_air_jumps -= 1
			velocity.y = DOUBLE_JUMP_VEL
			_jump_buffer = 0.0
			_flipping = true
			_flip_angle = 0.0
			_scale_x = 0.84
			_scale_y = 1.20
			SoundFX.play_double_jump()

	_slash_cd = maxf(0.0, _slash_cd - delta)
	if Input.is_action_just_pressed("slash") and _slash_cd <= 0.0:
		_start_slash()

	if slash_timer > 0.0:
		slash_timer -= delta
		for area in _slash_area.get_overlapping_areas():
			_handle_slash_hit(area)
		if slash_timer <= 0.0:
			_slash_area.monitoring = false

	_scale_x = lerpf(_scale_x, 1.0, minf(1.0, delta * 14.0))
	_scale_y = lerpf(_scale_y, 1.0, minf(1.0, delta * 14.0))
	if _flipping:
		_flip_angle += delta * 19.0
		if _flip_angle >= TAU:
			_flip_angle = 0.0
			_flipping = false

	move_and_slide()

	if _has_real_wall_crash():
		die("Crashed into building!")
		return
	if global_position.y > 900.0:
		die("Fell into the abyss!")
		return

	var anchor := global_position + Vector2(-8, -25)
	_scarf[0] = anchor
	for i in range(1, _scarf.size()):
		var prev := _scarf[i - 1]
		var curr := _scarf[i]
		curr.y += (32.0 + sin(_time * 14.0 + i) * 18.0) * delta
		curr.x -= 85.0 * delta
		var diff := curr - prev
		var d := diff.length()
		if d > 6.5 and d > 0.001:
			curr = prev + (diff / d) * 6.5
		_scarf[i] = curr
	_scarf_line.points = PackedVector2Array(_scarf)

	queue_redraw()

func _has_real_wall_crash() -> bool:
	if not is_on_wall():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().x < -0.7 and col.get_position().y < global_position.y - 7.0:
			return true
	return false

func _start_slash() -> void:
	slash_timer = SLASH_DURATION
	_slash_cd = SLASH_COOLDOWN
	_slash_area.monitoring = true
	_scale_x = 1.28
	_scale_y = 0.82
	SoundFX.play_slash()

func _on_slash_area_entered(area: Area2D) -> void:
	if slash_timer > 0.0:
		_handle_slash_hit(area)

func _handle_slash_hit(area: Area2D) -> void:
	if area.has_method("slash_hit"):
		area.slash_hit()
		slashed_something.emit(area.global_position, false)
	elif area.has_method("slice_deflect"):
		area.slice_deflect()
		slashed_something.emit(area.global_position, true)

func die(reason: String) -> void:
	if dead:
		return
	dead = true
	active = false
	_scarf_line.visible = false
	_slash_area.monitoring = false
	SoundFX.play_death()
	died.emit(reason)
	queue_redraw()

func _draw() -> void:
	for img in _afterimages:
		var lp := to_local(img["pos"]) + Vector2(0, -17)
		var a: float = img["alpha"] * 0.28
		draw_circle(lp, 14.0, Color(0.22, 0.74, 0.97, a))

	if dead:
		return

	draw_set_transform(Vector2(0, -17), _flip_angle, Vector2(_scale_x, _scale_y))

	# Sleek curved Cat Tail
	var wag := sin(_time * 13.0) * 5.0
	draw_line(Vector2(-9, 8), Vector2(-22, -2 + wag), Color(0.14, 0.16, 0.28), 4.5, true)

	# Smooth rounded Cat Ninja silhouette (capsule-like body + head)
	draw_circle(Vector2(0, 4), 11.5, Color(0.07, 0.09, 0.16))
	draw_circle(Vector2(0, -7), 12.0, Color(0.09, 0.12, 0.20))

	# Pointed Cat Ears
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -13), Vector2(-14, -27), Vector2(-2, -16)]), Color(0.08, 0.10, 0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(2, -16), Vector2(14, -27), Vector2(11, -13)]), Color(0.08, 0.10, 0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(-9.5, -14), Vector2(-11.5, -22), Vector2(-4, -16)]), Color(0.95, 0.25, 0.38))
	draw_colored_polygon(PackedVector2Array([Vector2(4, -16), Vector2(11.5, -22), Vector2(9.5, -14)]), Color(0.95, 0.25, 0.38))

	# Crimson Headband
	draw_line(Vector2(-11, -12), Vector2(11, -12), Color(1.2, 0.22, 0.25), 5.0, true)

	# Glowing Amber Eyes (HDR for bloom!)
	draw_circle(Vector2(5.5, -7), 3.0, Color(1.3, 0.95, 0.20))
	draw_circle(Vector2(-1.5, -7), 2.4, Color(1.3, 0.95, 0.20))

	# Sheathed Katana or Active Sweeping Slash Arc
	if slash_timer <= 0.0:
		draw_line(Vector2(-10, 6), Vector2(-20, -22), Color(0.75, 0.82, 0.92), 2.5, true)
		draw_line(Vector2(-17, -16), Vector2(-22, -24), Color(1.1, 0.82, 0.2), 2.2, true)
	else:
		var prog := 1.0 - clampf(slash_timer / SLASH_DURATION, 0.0, 1.0)
		var alpha := clampf(1.0 - prog * 0.85, 0.0, 1.0)
		var blade_angle := lerpf(-1.5, 1.15, prog)
		var tip := Vector2(cos(blade_angle), sin(blade_angle)) * 62.0 + Vector2(12, -4)
		draw_line(Vector2(6, -2), tip, Color(1.4, 1.45, 1.55, alpha), 4.0, true)
		draw_arc(Vector2(14, -4), 48.0 + prog * 14.0, -1.25, 1.15, 22, Color(0.30, 1.25, 1.65, alpha * 0.85), 11.0 * alpha, true)
		draw_arc(Vector2(16, -4), 52.0 + prog * 14.0, -1.15, 1.05, 22, Color(1.5, 1.5, 1.5, alpha), 3.8 * alpha, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
