extends Area2D
class_name EnemyBullet
## Fast-moving enemy projectile. Kills the Cat Ninja on contact unless sliced/deflected by a Katana Slash.

var velocity: Vector2 = Vector2(-520.0, 0.0)
var life: float = 4.0
var deflected: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 4
	monitoring = true
	monitorable = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if deflected:
		return
	if body.has_method("die"):
		body.die("Shot by enemy!")
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if deflected and area.has_method("slash_hit"):
		area.slash_hit()
		queue_free()

func slice_deflect() -> void:
	if deflected:
		return
	deflected = true
	velocity = Vector2(absf(velocity.x) * 1.9, -40.0)
	life = 0.85
	SoundFX.play_deflect()
	queue_redraw()

func _draw() -> void:
	if deflected:
		var dir := velocity.normalized()
		draw_line(Vector2.ZERO, -dir * 32.0, Color(0.22, 0.74, 0.97, 0.75), 6.0)
		draw_circle(Vector2.ZERO, 9.0, Color(0.22, 0.74, 0.97, 0.85))
		draw_circle(Vector2.ZERO, 4.5, Color.WHITE)
	else:
		var dir := velocity.normalized()
		draw_line(Vector2.ZERO, -dir * 26.0, Color(0.94, 0.27, 0.27, 0.65), 6.0)
		draw_circle(Vector2.ZERO, 9.0, Color(0.98, 0.45, 0.09, 0.5))
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.92, 0.55))
