extends Area2D
class_name EnemyGunner
## Gun-wielding cyber-syndicate enemy that telegraphs, fires bullets, and can be sliced in half.

signal enemy_slashed(world_pos: Vector2)

@export var fire_interval: float = 1.25
@export var aggro_range: float = 760.0
@export var bullet_speed: float = 490.0

var player_ref: Node2D = null
var bullet_container: Node2D = null
var _cooldown: float = 0.30
var _telegraph: float = 0.0
var _muzzle_flash: float = 0.0
var _slashed: bool = false
var _slash_anim: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	monitorable = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 42)
	shape.shape = rect
	shape.position = Vector2(0, -21)
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _muzzle_flash > 0.0:
		_muzzle_flash = maxf(0.0, _muzzle_flash - delta * 8.0)

	if _slashed:
		_slash_anim += delta
		if _slash_anim > 0.55:
			queue_free()
		queue_redraw()
		return

	if player_ref == null or not is_instance_valid(player_ref):
		return
	if player_ref.get("dead"):
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= aggro_range and player_ref.global_position.x < global_position.x + 40.0:
		_aim_dir = (player_ref.global_position + Vector2(0, -18) - (global_position + Vector2(-14, -25))).normalized()
		_cooldown -= delta
		if _cooldown <= 0.28 and _cooldown > 0.0:
			_telegraph = 1.0 - (_cooldown / 0.28)
		elif _cooldown <= 0.0:
			_fire_bullet()
			_cooldown = fire_interval
			_telegraph = 0.0
	else:
		_telegraph = 0.0

	queue_redraw()

func _fire_bullet() -> void:
	if bullet_container == null:
		return
	var b := EnemyBullet.new()
	b.global_position = global_position + Vector2(-22, -25)
	b.velocity = _aim_dir * bullet_speed
	bullet_container.add_child(b)
	_muzzle_flash = 1.0
	SoundFX.play_shoot()

func _on_body_entered(body: Node) -> void:
	if _slashed:
		return
	if body.has_method("die"):
		if body.get("slash_timer") != null and body.slash_timer > 0.0:
			slash_hit()
		else:
			body.die("Hit by enemy gunner!")

func slash_hit() -> void:
	if _slashed:
		return
	_slashed = true
	_slash_anim = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	SoundFX.play_kill()
	enemy_slashed.emit(global_position + Vector2(0, -22))
	queue_redraw()

func _draw() -> void:
	if _slashed:
		var t := clampf(_slash_anim / 0.55, 0.0, 1.0)
		var alpha := clampf(1.0 - pow(t, 1.4), 0.0, 1.0)
		var split := t * 140.0

		# Subtle fading ring
		draw_arc(Vector2(0, -22), 14.0 + t * 50.0, 0.0, TAU, 24, Color(0.30, 1.05, 1.35, alpha * 0.40), 2.2 * alpha, true)

		# Top half launching up-right with gentle spin
		draw_set_transform(Vector2(split * 0.45, -32 - split * 0.55), t * 1.4, Vector2.ONE)
		draw_rect(Rect2(-12, -10, 24, 20), Color(0.22, 0.25, 0.36, alpha))
		draw_rect(Rect2(-13, -10, 26, 6), Color(1.1, 0.22, 0.25, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Bottom half sliding down-left with counter-rotation
		draw_set_transform(Vector2(-split * 0.35, -10 + split * 0.3), -t * 1.0, Vector2.ONE)
		draw_rect(Rect2(-12, -10, 24, 20), Color(0.15, 0.17, 0.26, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Clean single diagonal cut line
		var cut_alpha := clampf(1.0 - t * 2.4, 0.0, 1.0)
		if cut_alpha > 0.0:
			draw_line(Vector2(-44, 10), Vector2(50, -54), Color(0.30, 1.05, 1.35, cut_alpha * 0.70), 3.5, true)
			draw_line(Vector2(-44, 10), Vector2(50, -54), Color(1.20, 1.20, 1.20, cut_alpha * 0.80), 1.4, true)
		return

	# Tactical Gunner Legs
	draw_rect(Rect2(-10, -14, 7, 14), Color(0.10, 0.12, 0.19))
	draw_rect(Rect2(3, -14, 7, 14), Color(0.10, 0.12, 0.19))

	# Armored Torso
	draw_rect(Rect2(-12, -38, 24, 26), Color(0.15, 0.18, 0.28))
	draw_rect(Rect2(-12, -38, 24, 26), Color(0.32, 0.38, 0.50), false, 1.5)
	draw_rect(Rect2(-13, -38, 26, 6), Color(0.86, 0.15, 0.15))

	# Helmet & Glowing Cyber Visor
	draw_circle(Vector2(0, -42), 10.5, Color(0.10, 0.12, 0.20))
	draw_rect(Rect2(-10, -45, 13, 4.5), Color(0.98, 0.22, 0.22))

	# Cyber Rifle
	draw_rect(Rect2(-26, -28, 22, 5.5), Color(0.45, 0.52, 0.62))
	draw_rect(Rect2(-28, -27, 6, 3.5), Color(0.94, 0.27, 0.27))
	draw_rect(Rect2(-11, -24, 5, 9), Color(0.28, 0.33, 0.42))

	var muzzle := Vector2(-28, -25.5)
	if _muzzle_flash > 0.0:
		draw_circle(muzzle, 10.0 * _muzzle_flash, Color(1.0, 0.75, 0.25, 0.85 * _muzzle_flash))
		draw_circle(muzzle, 5.0 * _muzzle_flash, Color.WHITE)

	if _telegraph > 0.0:
		draw_line(muzzle, muzzle + _aim_dir * 180.0, Color(0.98, 0.2, 0.2, 0.45 * _telegraph), 1.8)
		draw_circle(muzzle, 4.0 + _telegraph * 6.0, Color(1.0, 0.55, 0.15, 0.8 * _telegraph))
