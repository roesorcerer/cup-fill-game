extends Node3D

@export var bug_scene: PackedScene
@export var spawn_interval := 0.6
@export var bugs_per_spawn := 1
@export var spawn_area_path: NodePath = ^"../SpawnArea/CollisionShape3D"
@export var player_path: NodePath = ^"../Player"
@export var floor_y := 2.0
@export var wall_margin := 3.0

# --- SFX  ---
@export var sfx_spawn: AudioStream

@onready var spawn_shape: CollisionShape3D = get_node(spawn_area_path)
@onready var player: Node3D = get_node_or_null(player_path)

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.autostart = false
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_spawn_wave)

func start() -> void:
	_timer.start()

func stop() -> void:
	_timer.stop()

func _spawn_wave() -> void:
	if bug_scene == null or spawn_shape == null:
		return

	var box := spawn_shape.shape as BoxShape3D
	if box == null:
		return

	var extents := box.size * 0.5
	var spawn_x := extents.x - wall_margin
	var spawn_z := extents.z - wall_margin

	AudioHelper.play_one_shot_3d(get_tree(), sfx_spawn, spawn_shape.global_position)

	for i in range(bugs_per_spawn):
		var bug := bug_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(bug)

		var x := randf_range(-spawn_x, spawn_x)
		var z := randf_range(-spawn_z, spawn_z)

		var pos := spawn_shape.global_position
		pos.x += x
		pos.z += z
		pos.y = floor_y + 0.2

		bug.global_position = pos

		if player and bug.has_method("set_target"):
			bug.call("set_target", player)
