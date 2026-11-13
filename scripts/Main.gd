extends Node2D
## Extreme overhaul of Kage-Neko Dash: multi-layer cyberpunk/dojo visuals, hitstop, combos, jump pads & dash orbs.

@onready var camera: Camera2D = $Camera2D
@onready var player: CatNinjaPlayer = $Player
@onready var solids_container: Node2D = $SolidsContainer
@onready var spikes_container: Node2D = $SpikesContainer
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var bullets_container: Node2D = $BulletsContainer

# HUD
@onready var progress_bar: ProgressBar = $HUD/TopBar/ProgressBox/ProgressBar
@onready var progress_label: Label = $HUD/TopBar/ProgressBox/ProgressLabel
@onready var stage_label: Label = $HUD/TopBar/LeftInfo/StageLabel
@onready var attempt_label: Label = $HUD/TopBar/LeftInfo/AttemptLabel
@onready var slash_label: Label = $HUD/TopBar/RightInfo/SlashLabel
@onready var mute_btn: Button = $HUD/TopBar/RightInfo/MuteBtn
@onready var menu_btn: Button = $HUD/TopBar/RightInfo/MenuBtn

# Overlays
@onready var menu_overlay: Control = $HUD/MenuOverlay
@onready var stage_buttons_box: GridContainer = $HUD/MenuOverlay/Panel/VBox/StageButtons
@onready var play_btn: Button = $HUD/MenuOverlay/Panel/VBox/PlayBtn
@onready var clear_overlay: Control = $HUD/ClearOverlay
@onready var clear_title: Label = $HUD/ClearOverlay/Panel/VBox/ClearTitle
@onready var clear_stats: Label = $HUD/ClearOverlay/Panel/VBox/ClearStats
@onready var next_btn: Button = $HUD/ClearOverlay/Panel/VBox/Buttons/NextBtn
@onready var replay_btn: Button = $HUD/ClearOverlay/Panel/VBox/Buttons/ReplayBtn

var levels: Array[Dictionary] = []
var current_level_idx: int = 0
var current_level: Dictionary = {}
var attempt: int = 1
var slashed_count: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var best_progress: Dictionary = {}

var _respawn_timer: float = -1.0
var _hitstop_timer: float = 0.0
var _shake: float = 0.0
var _stage_cleared: bool = false
var _time: float = 0.0

var _particles: Array[Dictionary] = []
var _slash_effects: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _petals: Array[Dictionary] = []
var _orbs: Array[Dictionary] = []

const SAVE_PATH := "user://kage_neko_dash.cfg"

func _ready() -> void:
	levels = LevelData.get_levels()
	_load_save()
	_init_ambient()

	player.died.connect(_on_player_died)
	player.slashed_something.connect(_on_player_slashed)

	play_btn.pressed.connect(func(): start_stage(current_level_idx, true))
	replay_btn.pressed.connect(func():
		var target_idx := 0 if current_level_idx + 1 >= levels.size() and _stage_cleared else current_level_idx
		start_stage(target_idx, true)
	)
	next_btn.pressed.connect(_on_next_stage)
	mute_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.pressed.connect(_on_toggle_mute)
	menu_btn.pressed.connect(_show_menu)

	_apply_panel_styles()
	_build_stage_buttons()
	_load_stage_geometry(0)
	_show_menu()

func _apply_panel_styles() -> void:
	for panel_path in ["HUD/MenuOverlay/Panel", "HUD/ClearOverlay/Panel"]:
		var panel := get_node_or_null(panel_path) as PanelContainer
		if panel:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.07, 0.14, 0.94)
			sb.border_color = Color(0.22, 0.74, 0.97, 0.55)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(16)
			sb.set_content_margin_all(28)
			panel.add_theme_stylebox_override("panel", sb)

func _init_ambient() -> void:
	for i in 80:
		_stars.append({"x": randf(), "y": randf() * 0.65, "r": randf_range(0.8, 2.2), "phase": randf() * TAU, "speed": randf_range(1.5, 4.0)})
	for i in 38:
		_petals.append({"x": randf() * 1400.0, "y": randf() * 800.0, "vx": randf_range(-160.0, -90.0), "vy": randf_range(18.0, 48.0), "size": randf_range(3.0, 6.5)})

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for lvl in levels:
			var id_str := str(lvl["id"])
			best_progress[id_str] = cfg.get_value("best", id_str, 0)
		current_level_idx = clampi(int(cfg.get_value("progress", "unlocked_idx", 0)), 0, levels.size() - 1)

func _save_unlocked(idx: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var prev: int = int(cfg.get_value("progress", "unlocked_idx", 0))
	if idx > prev:
		cfg.set_value("progress", "unlocked_idx", clampi(idx, 0, levels.size() - 1))
		cfg.save(SAVE_PATH)

func _save_best(level_id: int, pct: int) -> void:
	var id_str := str(level_id)
	var prev: int = best_progress.get(id_str, 0)
	if pct > prev:
		best_progress[id_str] = pct
		var cfg := ConfigFile.new()
		cfg.load(SAVE_PATH)
		cfg.set_value("best", id_str, pct)
		cfg.save(SAVE_PATH)

func _build_stage_buttons() -> void:
	for child in stage_buttons_box.get_children():
		child.queue_free()

	for i in levels.size():
		var lvl: Dictionary = levels[i]
		var btn := Button.new()
		var best: int = best_progress.get(str(lvl["id"]), 0)
		btn.text = "Stage %d: %s\nBest: %d%%" % [lvl["id"], lvl["name"], best]
		btn.custom_minimum_size = Vector2(165, 64)
		btn.pressed.connect(func():
			current_level_idx = i
			play_btn.text = "PLAY STAGE %d" % lvl["id"]
			_highlight_stage_btn()
		)
		stage_buttons_box.add_child(btn)
	_highlight_stage_btn()

func _highlight_stage_btn() -> void:
	var children := stage_buttons_box.get_children()
	for i in children.size():
		var btn := children[i] as Button
		btn.modulate = Color(1.0, 0.55, 0.55) if i == current_level_idx else Color(0.85, 0.88, 0.95)

func _show_menu() -> void:
	player.active = false
	_respawn_timer = -1.0
	SoundFX.set_progress(0.0)
	stage_buttons_box.visible = false
	play_btn.text = "PLAY" if current_level_idx <= 0 else "CONTINUE"
	menu_overlay.visible = true
	clear_overlay.visible = false

func start_stage(idx: int, reset_attempts: bool) -> void:
	current_level_idx = idx
	if reset_attempts:
		attempt = 1
	_stage_cleared = false
	_respawn_timer = -1.0
	_hitstop_timer = 0.0
	slashed_count = 0
	combo_count = 0
	combo_timer = 0.0
	SoundFX.set_progress(0.0)
	menu_overlay.visible = false
	clear_overlay.visible = false
	_load_stage_geometry(idx)
	SoundFX.set_stage(current_level["id"])
	player.reset_at(Vector2(140, 540), current_level["speed"])
	camera.global_position = Vector2(player.global_position.x + 260.0, 380.0)

func _load_stage_geometry(idx: int) -> void:
	current_level = levels[idx]

	for container in [solids_container, spikes_container, enemies_container, bullets_container]:
		for c in container.get_children():
			container.remove_child(c)
			c.queue_free()
	_particles.clear()
	_slash_effects.clear()
	_orbs.clear()

	for s in current_level["solids"]:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(s["w"], s["h"])
		col.shape = rect
		col.position = Vector2(s["x"] + s["w"] * 0.5, s["y"] + s["h"] * 0.5)
		body.add_child(col)
		solids_container.add_child(body)

	for sp in current_level["spikes"]:
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(sp["w"] - 10.0, 14.0)
		col.shape = rect
		col.position = Vector2(sp["x"] + sp["w"] * 0.5, sp["y"] + 9.0)
		area.add_child(col)
		area.body_entered.connect(func(b):
			if b.has_method("die"):
				b.die("Hit spikes!")
		)
		spikes_container.add_child(area)

	# Gold Jump Pads
	for pd in current_level.get("pads", []):
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(pd["w"], 14.0)
		col.shape = rect
		col.position = Vector2(pd["x"] + pd["w"] * 0.5, pd["y"] + 7.0)
		area.add_child(col)
		area.body_entered.connect(func(b):
			if b == player and not player.dead:
				player.pad_launch()
				_spawn_burst(Vector2(pd["x"] + pd["w"] * 0.5, pd["y"]), Color(0.98, 0.75, 0.14), 14, 220.0)
		)
		spikes_container.add_child(area)

	# Cyan Dash Orbs
	for ob in current_level.get("orbs", []):
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.position = Vector2(ob["x"], ob["y"])
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		col.shape = circle
		area.add_child(col)
		var orb_entry := {"pos": Vector2(ob["x"], ob["y"]), "inside": false, "used": false}
		area.body_entered.connect(func(b):
			if b == player:
				orb_entry["inside"] = true
		)
		area.body_exited.connect(func(b):
			if b == player:
				orb_entry["inside"] = false
				orb_entry["used"] = false
		)
		spikes_container.add_child(area)
		_orbs.append(orb_entry)

	for g in current_level["gunners"]:
		var enemy := EnemyGunner.new()
		enemy.global_position = Vector2(g["x"], g["y"])
		enemy.fire_interval = g.get("rate", 1.25)
		enemy.player_ref = player
		enemy.bullet_container = bullets_container
		enemy.enemy_slashed.connect(_on_enemy_killed)
		enemies_container.add_child(enemy)

	stage_label.text = "Stage %d: %s" % [current_level["id"], current_level["name"]]
	attempt_label.text = "Attempt #%d" % attempt
	slash_label.text = "Slashed: 0"
	progress_bar.value = 0.0
	progress_label.text = "0%"
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta

	if Input.is_action_just_pressed("restart") and not menu_overlay.visible:
		attempt += 1
		start_stage(current_level_idx, false)
		return

	# Hitstop micro-freeze for punchy katana impact
	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		player.set_physics_process(false)
		return
	else:
		player.set_physics_process(true)

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			slash_label.text = "Slashed: %d" % slashed_count

	# Dash Orb trigger
	for ob in _orbs:
		if ob["inside"] and not ob["used"] and Input.is_action_just_pressed("jump"):
			ob["used"] = true
			player.orb_boost()
			_spawn_burst(ob["pos"], Color(0.22, 0.74, 0.97), 16, 250.0)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 36.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		camera.offset = Vector2.ZERO
	camera.zoom = camera.zoom.lerp(Vector2.ONE, minf(1.0, delta * 12.0))

	for p in _petals:
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		if p["x"] < -20.0:
			p["x"] = 1420.0
		if p["y"] > 820.0:
			p["y"] = -20.0
			p["x"] = randf() * 1400.0

	for i in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[i]
		pt["pos"] += pt["vel"] * delta
		pt["vel"].y += 600.0 * delta
		pt["life"] -= delta
		if pt["life"] <= 0.0:
			_particles.remove_at(i)

	for i in range(_slash_effects.size() - 1, -1, -1):
		var se: Dictionary = _slash_effects[i]
		se["life"] -= delta
		if se["life"] <= 0.0:
			_slash_effects.remove_at(i)

	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			attempt += 1
			start_stage(current_level_idx, false)

	if player.active and not player.dead and not _stage_cleared:
		var target_cam_x: float = player.global_position.x + 290.0
		var target_cam_y: float = clampf(player.global_position.y - 70.0, 260.0, 420.0)
		camera.global_position.x = target_cam_x
		camera.global_position.y = lerpf(camera.global_position.y, target_cam_y, minf(1.0, delta * 7.0))

		var goal_x: float = current_level["goal_x"]
		var pct: float = clampf((player.global_position.x - 140.0) / (goal_x - 140.0), 0.0, 1.0)
		SoundFX.set_progress(pct)
		var pct_int: int = int(round(pct * 100.0))
		progress_bar.value = pct_int
		progress_label.text = "%d%%" % pct_int

		if player.global_position.x >= goal_x:
			_on_stage_clear()

	queue_redraw()

func _on_player_died(_reason: String) -> void:
	_shake = 14.0
	_spawn_burst(player.global_position + Vector2(0, -16), Color(0.94, 0.27, 0.27), 24, 280.0)
	var pct := int(round(progress_bar.value))
	_save_best(current_level["id"], pct)
	_respawn_timer = 0.55

func _on_player_slashed(world_pos: Vector2, is_bullet: bool) -> void:
	_shake = 3.0
	_hitstop_timer = 0.020
	camera.zoom = Vector2(1.015, 1.015)
	combo_count += 1
	combo_timer = 2.6
	if is_bullet:
		slash_label.text = "Slashed: %d (x%d DEFLECT!)" % [slashed_count, combo_count]
		_slash_effects.append({"pos": world_pos, "life": 0.20, "max_life": 0.20, "radius": 36.0, "color": Color(0.30, 0.95, 1.25)})
	_spawn_burst(world_pos, Color(0.25, 0.90, 1.25), 8, 200.0)

func _on_enemy_killed(world_pos: Vector2) -> void:
	slashed_count += 1
	_shake = 4.0
	_hitstop_timer = 0.025
	camera.zoom = Vector2(1.018, 1.018)
	slash_label.text = "Slashed: %d (x%d)" % [slashed_count, maxi(1, combo_count)]
	_slash_effects.append({"pos": world_pos, "life": 0.24, "max_life": 0.24, "radius": 58.0, "color": Color(0.30, 1.05, 1.35)})
	_spawn_burst(world_pos, Color(1.05, 0.78, 0.25), 10, 220.0)

func _on_stage_clear() -> void:
	_stage_cleared = true
	player.active = false
	SoundFX.play_win()
	_save_best(current_level["id"], 100)
	if current_level_idx + 1 < levels.size():
		_save_unlocked(current_level_idx + 1)
	progress_bar.value = 100
	progress_label.text = "100%"

	var is_final := current_level_idx + 1 >= levels.size()
	if is_final:
		clear_title.text = "YOU COMPLETED THE GAME!"
		clear_stats.text = "Every shadow trial conquered!\nAttempts: %d   •   Enemies Slashed: %d" % [attempt, slashed_count]
		replay_btn.text = "Play From Stage 1"
		var p_pos := player.global_position + Vector2(0, -30)
		_spawn_burst(p_pos, Color(1.30, 0.95, 0.22), 36, 420.0)
		_spawn_burst(p_pos + Vector2(-90, -50), Color(0.35, 1.35, 1.65), 28, 380.0)
		_spawn_burst(p_pos + Vector2(90, -50), Color(1.25, 0.45, 0.85), 28, 380.0)
	else:
		clear_title.text = "%s Cleared!" % current_level["name"]
		clear_stats.text = "Attempts: %d   •   Enemies Slashed: %d" % [attempt, slashed_count]
		replay_btn.text = "Replay"
	next_btn.visible = not is_final
	clear_overlay.visible = true

func _on_next_stage() -> void:
	if current_level_idx + 1 < levels.size():
		start_stage(current_level_idx + 1, true)

func _on_toggle_mute() -> void:
	SoundFX.muted = not SoundFX.muted
	mute_btn.text = "Sound: OFF" if SoundFX.muted else "Sound: ON"
	mute_btn.release_focus()

func _spawn_burst(pos: Vector2, color: Color, count: int, max_spd: float = 340.0) -> void:
	for i in count:
		var angle := randf() * TAU
		var spd := randf_range(90.0, max_spd)
		_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd - 80.0),
			"color": color,
			"size": randf_range(2.5, 5.5),
			"life": randf_range(0.25, 0.52),
			"max_life": 0.52,
		})

func _draw() -> void:
	if current_level.is_empty():
		return

	var cam_x: float = camera.global_position.x
	var cam_y: float = camera.global_position.y

	# 1. Smooth Vertical Sky Gradient & Twinkling Stars
	var sky_rect := PackedVector2Array([
		Vector2(cam_x - 850.0, cam_y - 550.0),
		Vector2(cam_x + 950.0, cam_y - 550.0),
		Vector2(cam_x + 950.0, cam_y + 550.0),
		Vector2(cam_x - 850.0, cam_y + 550.0),
	])
	var sky_top: Color = current_level["sky_top"]
	var sky_bot: Color = current_level["sky_bot"]
	draw_polygon(sky_rect, PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))

	for st in _stars:
		var a: float = 0.25 + 0.55 * (0.5 + 0.5 * sin(_time * float(st["speed"]) + float(st["phase"])))
		var sx: float = cam_x - 640.0 + float(st["x"]) * 1280.0
		var sy: float = cam_y - 360.0 + float(st["y"]) * 720.0
		draw_circle(Vector2(sx, sy), float(st["r"]), Color(0.89, 0.91, 0.96, a))

	# 2. HDR Full Moon with Soft Halo
	var moon_pos := Vector2(cam_x + 340.0 - cam_x * 0.03, cam_y - 160.0)
	draw_circle(moon_pos, 110.0, Color(0.99, 0.96, 0.78, 0.08))
	draw_circle(moon_pos, 46.0, Color(1.15, 1.08, 0.85, 0.95))

	# 3. Parallax Pagoda / Cyber Skyline (clean skyline without jagged spikes)
	var mid_step := 170.0
	var mid_start := floorf((cam_x - 950.0) / mid_step) * mid_step
	for i in 12:
		var bx := mid_start + i * mid_step - cam_x * 0.18
		var bh := 135.0 + fmod(absf(cos(bx * 0.019)) * 170.0, 150.0)
		draw_rect(Rect2(bx, 720.0 - bh, 118.0, bh + 150.0), Color(0.06, 0.08, 0.17, 0.72))
		# Pagoda eave silhouette on midground towers
		var roof_pts := PackedVector2Array([
			Vector2(bx - 12.0, 720.0 - bh + 8.0),
			Vector2(bx + 59.0, 720.0 - bh - 14.0),
			Vector2(bx + 130.0, 720.0 - bh + 8.0),
		])
		draw_colored_polygon(roof_pts, Color(0.08, 0.10, 0.21, 0.85))

	# 4. Solids: Ground, Pagoda Buildings & Enclosed Tunnels
	var ground_trim: Color = current_level["ground_trim"]
	var roof_trim: Color = current_level["roof_trim"]
	var tunnel_trim: Color = current_level["tunnel_trim"]
	var win_col: Color = current_level["window_col"]

	for s in current_level["solids"]:
		var r := Rect2(s["x"], s["y"], s["w"], s["h"])
		if r.end.x < cam_x - 850.0 or r.position.x > cam_x + 950.0:
			continue

		var kind: String = s["kind"]
		if kind == "ceiling":
			# Background tunnel pillars & dark interior backing
			draw_rect(Rect2(r.position.x + 12.0, r.end.y, r.size.x - 24.0, 180.0), Color(0.03, 0.04, 0.08, 0.55))
			var px := r.position.x + 30.0
			while px < r.end.x - 30.0:
				draw_rect(Rect2(px, r.end.y, 16.0, 175.0), Color(0.07, 0.09, 0.16, 0.75))
				px += 160.0

			# Overhead tunnel structure + hazard lip + light cones
			draw_rect(r, Color(0.07, 0.09, 0.16))
			draw_rect(r, Color(0.20, 0.26, 0.38), false, 1.5)
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), tunnel_trim, 4.5, true)
			var lx := r.position.x + 56.0
			while lx < r.end.x - 56.0:
				draw_line(Vector2(lx, r.end.y - 10.0), Vector2(lx + 40.0, r.end.y - 10.0), ground_trim, 3.0, true)
				# Soft light cone shining into tunnel
				var cone := PackedVector2Array([
					Vector2(lx, r.end.y),
					Vector2(lx + 40.0, r.end.y),
					Vector2(lx + 72.0, r.end.y + 165.0),
					Vector2(lx - 32.0, r.end.y + 165.0),
				])
				draw_colored_polygon(cone, Color(ground_trim.r, ground_trim.g, ground_trim.b, 0.055))
				lx += 150.0
		elif kind == "building":
			draw_rect(r, Color(0.08, 0.10, 0.19))
			draw_rect(r, Color(0.18, 0.24, 0.38), false, 1.5)
			# Flared Japanese pagoda roof cap
			var eave := PackedVector2Array([
				Vector2(r.position.x - 10.0, r.position.y + 8.0),
				Vector2(r.position.x - 2.0, r.position.y),
				Vector2(r.end.x + 2.0, r.position.y),
				Vector2(r.end.x + 10.0, r.position.y + 8.0),
				Vector2(r.end.x + 4.0, r.position.y + 12.0),
				Vector2(r.position.x - 4.0, r.position.y + 12.0),
			])
			draw_colored_polygon(eave, Color(0.14, 0.17, 0.28))
			draw_line(Vector2(r.position.x - 8.0, r.position.y + 2.0), Vector2(r.end.x + 8.0, r.position.y + 2.0), roof_trim, 4.5, true)
			var wx := r.position.x + 18.0
			while wx < r.end.x - 22.0:
				var wy := r.position.y + 24.0
				while wy < minf(r.end.y - 24.0, r.position.y + 130.0):
					draw_rect(Rect2(wx, wy, 8.0, 12.0), win_col)
					wy += 28.0
				wx += 28.0
		else:
			draw_rect(r, Color(0.06, 0.09, 0.16))
			# Vertical cyber-tatami floor seams
			var gx_line := r.position.x + 48.0
			while gx_line < r.end.x - 20.0:
				draw_line(Vector2(gx_line, r.position.y + 4.0), Vector2(gx_line, r.position.y + 48.0), Color(ground_trim.r, ground_trim.g, ground_trim.b, 0.12), 1.5)
				gx_line += 64.0
			draw_line(Vector2(r.position.x, r.position.y + 1.5), Vector2(r.end.x, r.position.y + 1.5), ground_trim, 4.0, true)

	# 5. Spikes
	for sp in current_level["spikes"]:
		var sx := float(sp["x"])
		var sy := float(sp["y"])
		var sw := float(sp["w"])
		var count := maxi(1, int(sw / 16.0))
		var step := sw / float(count)
		for i in count:
			var x0 := sx + i * step
			var pts := PackedVector2Array([Vector2(x0, sy + 16.0), Vector2(x0 + step * 0.5, sy), Vector2(x0 + step, sy + 16.0)])
			draw_colored_polygon(pts, Color(0.92, 0.95, 0.99))
			draw_line(Vector2(x0, sy + 16.0), Vector2(x0 + step, sy + 16.0), Color(1.25, 0.25, 0.25), 2.5, true)

	# 6. Gold Jump Pads
	for pd in current_level.get("pads", []):
		var pr := Rect2(pd["x"], pd["y"], pd["w"], 12.0)
		draw_rect(pr, Color(1.25, 0.85, 0.18))

	# 7. Cyan Dash Orbs (HDR glow)
	for ob in _orbs:
		var op: Vector2 = ob["pos"]
		var pulse := 20.0 + sin(_time * 6.0) * 3.0
		draw_circle(op, pulse, Color(0.22, 0.74, 0.97, 0.22))
		draw_arc(op, 16.0, 0.0, TAU, 28, Color(0.30, 1.10, 1.40), 3.5, true)
		draw_circle(op, 7.0, Color(1.2, 1.2, 1.2))

	# 8. Crimson Torii Goal Gate
	var gx: float = current_level["goal_x"]
	draw_circle(Vector2(gx + 32.0, 470.0), 65.0, Color(0.98, 0.75, 0.14, 0.14))
	draw_rect(Rect2(gx, 410.0, 10.0, 130.0), Color(1.15, 0.20, 0.22))
	draw_rect(Rect2(gx + 54.0, 410.0, 10.0, 130.0), Color(1.15, 0.20, 0.22))
	draw_rect(Rect2(gx - 10.0, 400.0, 84.0, 12.0), Color(1.25, 0.25, 0.25))
	draw_circle(Vector2(gx + 32.0, 460.0 + sin(_time * 4.0) * 5.0), 14.0, Color(1.30, 0.95, 0.22))

	# 9. Enemy/Deflect Slash Effects, Particles & High-Speed Sakura Petals
	for se in _slash_effects:
		var prog := 1.0 - clampf(float(se["life"]) / float(se["max_life"]), 0.0, 1.0)
		var sa := clampf(1.0 - prog, 0.0, 1.0)
		var sp: Vector2 = se["pos"]
		var rad := float(se["radius"])
		var sc: Color = se["color"]
		# Subtle fading ring + clean single diagonal katana cut line
		draw_arc(sp, 12.0 + prog * rad, 0.0, TAU, 24, Color(sc.r, sc.g, sc.b, sa * 0.40), 2.2 * sa, true)
		var cut_a := clampf(1.0 - prog * 1.7, 0.0, 1.0)
		if cut_a > 0.0:
			var reach := rad * (0.7 + prog * 0.2)
			draw_line(sp + Vector2(-reach, reach * 0.55), sp + Vector2(reach, -reach * 0.55), Color(sc.r, sc.g, sc.b, cut_a * 0.70), 3.6 * cut_a, true)
			draw_line(sp + Vector2(-reach * 0.9, reach * 0.50), sp + Vector2(reach * 0.9, -reach * 0.50), Color(1.2, 1.2, 1.2, cut_a * 0.80), 1.5 * cut_a, true)

	for pt in _particles:
		var a := clampf(pt["life"] / pt["max_life"], 0.0, 1.0)
		var c: Color = pt["color"]
		draw_circle(pt["pos"], pt["size"], Color(c.r, c.g, c.b, a))

	for p in _petals:
		draw_circle(Vector2(cam_x - 640.0 + float(p["x"]), cam_y - 360.0 + float(p["y"])), float(p["size"]) * 0.65, Color(0.99, 0.64, 0.69, 0.55))
