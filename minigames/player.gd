extends CharacterBody3D

signal player_died
signal bugs_collected(count: int)
signal hp_changed(norm: float)

@export var max_hp := 5
@export var speed := 14.0
@export var jump_velocity := 20.0
@export var fall_acceleration := 75.0

@export var mouse_sensitivity := 0.0025
@export var min_pitch := deg_to_rad(-60.0)
@export var max_pitch := deg_to_rad(20.0)

@export var collect_duration := 0.18
@export var flip_duration := 0.20
@export var flip_degrees := 90.0

# --- SFX  found in the Main Node inspector---
@export var sfx_death: AudioStream
@export var sfx_win: AudioStream

@export var captured_bug_scene: PackedScene
@export var bug_projectile_scene: PackedScene
@export var bug_throw_speed := 22.0

@onready var collect_area: Area3D = $Pivot/CupPivot/Cup/CollectArea
@onready var anim_target: Node3D = $Pivot/CupPivot
@onready var cup_center: Marker3D = $Pivot/CupPivot/Cup/CupInterior/Center

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var stomp_area: Area3D = $StompArea
@onready var visual_pivot: Node3D = $Pivot
@onready var catch_audio: AudioStreamPlayer3D = $Pivot/CupPivot/Cup/CatchAudio3D
@onready var bug_storage: Node3D = $Pivot/CupPivot/Cup/BugStorage
@onready var cup_interior_shape: CollisionShape3D = $Pivot/CupPivot/Cup/CupInterior/InteriorShape
@onready var death_audio: AudioStreamPlayer3D = $DeathAudio3D
@onready var death_particles: GPUParticles3D = $DeathParticles
@onready var win_particles: GPUParticles3D = $WinParticles

var move_input: Vector2 = Vector2.ZERO
var move_dir: Vector3 = Vector3.ZERO
var _is_collecting := false
var cup_is_open := false
var bug_ammo: int = 0
var can_shoot_bugs := false
var hp: int
var boss: Node = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stomp_area.body_entered.connect(_on_stomp_body_entered)
	hp = max_hp
	hp_changed.emit(1.0)

func _input(event: InputEvent) -> void:
	if not Input.is_action_pressed("right_click"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, min_pitch, max_pitch)

func _physics_process(delta: float) -> void:
	move_input = Input.get_vector("left", "right", "forward", "back")

	var cam_basis: Basis = camera_pivot.global_transform.basis
	var forward: Vector3 = cam_basis.z
	var right: Vector3 = cam_basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	move_dir = (right * move_input.x + forward * move_input.y)
	if move_dir.length() > 0.001:
		move_dir = move_dir.normalized()
		visual_pivot.look_at(global_position + move_dir, Vector3.UP)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= fall_acceleration * delta

	move_and_slide()

	if Input.is_action_just_pressed("collect"):
		collect_now()

	if can_shoot_bugs and Input.is_action_just_pressed("left_click"):
		_throw_bug()

func _on_stomp_body_entered(body: Node) -> void: #dont really use stomp anymore but whatever
	if body.is_in_group("bugs") and velocity.y <= 0.0:
		body.queue_free()

func collect_now() -> void:
	if _is_collecting:
		return
	_is_collecting = true

	cup_is_open = !cup_is_open

	var target_x := -flip_degrees if cup_is_open else 0.0

	var t := create_tween()
	t.tween_property(anim_target, "rotation_degrees:x", target_x, flip_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if not cup_is_open:
		_collect_bugs_in_rim()

	t.finished.connect(func():
		_is_collecting = false
	)

func _collect_bugs_in_rim() -> void:
	var bodies := collect_area.get_overlapping_bodies()
	var count := 0
#collecting bugs into the cup
	for b in bodies:
		if b and b.is_in_group("bugs"):
			count += 1
			_suck_bug_into_cup(b)

	if count > 0: #using bugs as ammo
		bug_ammo += count
		bugs_collected.emit(bug_ammo)

func _suck_bug_into_cup(bug: Node3D) -> void:
	if catch_audio and catch_audio.stream: #audio for catching
		catch_audio.play()

	var target := cup_center.global_position
	var tw := create_tween() #so it can start at the next process 
	tw.tween_property(bug, "global_position", target, collect_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.finished.connect(func(): #connecting to method 
		if not is_instance_valid(bug):
			return
		_spawn_captured_bug_in_cup()
		bug.queue_free()
	)

func _spawn_captured_bug_in_cup() -> void:
	if captured_bug_scene == null:
		push_warning("captured_bug_scene not set on Player.")
		return

	var stored := captured_bug_scene.instantiate() as Node3D
	bug_storage.add_child(stored)

	stored.position = _random_point_in_cup_interior()
	stored.rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)

func _random_point_in_cup_interior() -> Vector3: #to help with the bugs not going into the right part of the cup
	if cup_center == null:
		return Vector3.ZERO

	var angle := randf_range(0.0, TAU)
	var dist := sqrt(randf()) * 0.12
	var offset := Vector3(cos(angle) * dist, randf_range(-0.08, 0.08), sin(angle) * dist)

	var world := cup_center.global_position + offset
	return bug_storage.to_local(world)

func set_bug_ammo(amount: int) -> void:
	bug_ammo = max(amount, 0)
	bugs_collected.emit(bug_ammo)

func set_can_shoot_bugs(v: bool) -> void:
	can_shoot_bugs = v

func _throw_bug() -> void:
	if bug_projectile_scene == null:
		push_warning("bug_projectile_scene not set on Player.")
		return
	if bug_ammo <= 0:
		return

	bug_ammo -= 1
	bugs_collected.emit(bug_ammo)

	if bug_storage.get_child_count() > 0:
		bug_storage.get_child(bug_storage.get_child_count() - 1).queue_free()

	var proj := bug_projectile_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(proj)

	var target_pos: Vector3 #trying to get the correct point to target 
	if boss and boss.has_method("get_bug_target_point"):
		target_pos = boss.call("get_bug_target_point")
	else:
		target_pos = global_position + (-camera_pivot.global_transform.basis.z) * 20.0 + Vector3.UP * 2.0

	var dir := (target_pos - cup_center.global_position).normalized()

	#aim up a bit 
	dir.y += 0.18
	dir = dir.normalized()

	# position trying to correct where the cup center is
	proj.global_position = cup_center.global_position + dir * 0.6 + Vector3.UP * 0.2

	if proj.has_method("fire_dir"):
		proj.call("fire_dir", dir, bug_throw_speed)

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	hp_changed.emit(float(hp) / float(max_hp))
	if hp <= 0:
		player_died.emit()

func get_web_target_point() -> Vector3:
	return global_position + Vector3.UP * 2.0

func set_boss_ref(b: Node) -> void: #I might use something else 
	boss = b

func play_death_animation() -> void:
	set_physics_process(false)

	if sfx_death and death_audio:
		death_audio.stream = sfx_death
		death_audio.play()

	if death_particles:
		death_particles.emitting = true

	var t := create_tween() #I might be able to make this easier by isloating the death animation/flip
	t.set_parallel(true)

	t.tween_property(anim_target, "rotation_degrees:x", -flip_degrees, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	t.tween_property(visual_pivot, "rotation_degrees:z", randf_range(-15.0, 15.0), 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	t.tween_property(self, "position:y", position.y - 0.3, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func play_win_animation() -> void:
	if sfx_win and death_audio:
		death_audio.stream = sfx_win
		death_audio.play()

	if win_particles:
		win_particles.emitting = true

	var t := create_tween()
	t.set_parallel(true)

	t.tween_property(self, "position:y", position.y + 1.5, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(self, "position:y", position.y, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	t.parallel().tween_property(visual_pivot, "rotation_degrees:y", visual_pivot.rotation_degrees.y + 360, 0.8)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
