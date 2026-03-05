extends Node3D

signal boss_died
signal hp_changed(norm: float)

@export var max_hp := 5
@export var web_scene: PackedScene
@export var shoot_interval := 1.2
@export var web_speed := 18.0
@export var move_speed := 4.0
@export var stop_distance := 3.0

# --- SFX (assign in Inspector) ---
@export var sfx_shoot_web: AudioStream
@export var sfx_die: AudioStream
@export var sfx_player_attack: AudioStream

# --- Death "win" animation tuning ---
@export var death_anim_sec := 0.55

@onready var shoot_timer: Timer = $WebShootTimer
@onready var muzzle: Marker3D = $Muzzle

var hp: int
var player: Node3D

var _dying := false
var _is_fighting := false

func _ready() -> void:
	hp = max_hp
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_shoot_web)
	shoot_timer.stop()

func start_fight(p: Node3D) -> void:
	player = p
	hp = max_hp
	_dying = false
	_is_fighting = true
	set_physics_process(true)
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	hp_changed.emit(1.0)

func _physics_process(delta: float) -> void:
	if not _is_fighting or player == null:
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist <= stop_distance or dist < 0.01:
		return

	var dir := to_player / dist
	global_position += dir * move_speed * delta

	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(8.0 * delta, 0.0, 1.0))

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp = max(hp - amount, 0)
	AudioHelper.play_one_shot_3d(get_tree(), sfx_player_attack, global_position)
	hp_changed.emit(float(hp) / float(max_hp))
	if hp <= 0:
		_die()

func _die() -> void:
	if _dying:
		return
	_dying = true
	_is_fighting = false
	shoot_timer.stop()
	AudioHelper.play_one_shot_3d(get_tree(), sfx_die, global_position)
	set_physics_process(false)

	var start_scale := scale
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "rotation", rotation + Vector3(0.0, TAU, 0.0), death_anim_sec)
	t.tween_property(self, "scale", start_scale * 0.15, death_anim_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	await t.finished
	visible = false
	boss_died.emit()

func get_web_target_point() -> Vector3:
	return muzzle.global_position

func _shoot_web() -> void:
	if not _is_fighting or player == null or web_scene == null or muzzle == null:
		return
	AudioHelper.play_one_shot_3d(get_tree(), sfx_shoot_web, global_position)

	var web := web_scene.instantiate()
	get_tree().current_scene.add_child(web)
	var spawn_xform := muzzle.global_transform
	spawn_xform.origin += -muzzle.global_transform.basis.z * 1.2
	spawn_xform.origin += Vector3.UP * 0.4
	web.global_transform = spawn_xform

	var target_pos: Vector3
	if player.has_method("get_web_target_point"):
		target_pos = player.call("get_web_target_point")
	else:
		target_pos = player.global_position + Vector3.UP * 2.0

	web.call("fire_at", target_pos, web_speed)

func get_bug_target_point() -> Vector3:
	return global_position + Vector3.UP * 2.0
