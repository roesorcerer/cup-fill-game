extends RigidBody3D


#Exports 
@export var max_speed: float = 6.0
@export var acceleration: float = 18.0
@export var flee_distance: float = 9.0
@export var wander_change_time: float = 0.8
@export var wander_strength: float = 0.6
@export var turn_speed: float = 10.0

#local Vars
var target: Node3D = null
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_t: float = 0.0


func set_target(t: Node3D) -> void:
	target = t

func _ready() -> void:
	add_to_group("bugs") 
	lock_rotation = true
	_pick_wander_dir()

func _physics_process(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_pick_wander_dir()
	var desired_dir: Vector3 = _wander_dir
	if target:
		var to_target: Vector3 = target.global_position - global_position
		var dist: float = to_target.length()
		if dist > 0.001 and dist < flee_distance:
			var flee_dir := (-to_target).normalized()
			desired_dir = (flee_dir + _wander_dir * wander_strength).normalized()

	desired_dir.y = 0.0
	if desired_dir.length() < 0.001:
		return

	var desired_vel: Vector3 = desired_dir * max_speed
	linear_velocity = linear_velocity.move_toward(desired_vel, acceleration * delta)


	var flat_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_vel.length() > 0.2:
		_face(flat_vel.normalized(), delta)

func _pick_wander_dir() -> void:
	_wander_t = wander_change_time + randf() * 0.5
	var a := randf_range(0.0, TAU)
	_wander_dir = Vector3(cos(a), 0.0, sin(a)).normalized()

func _face(dir: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
