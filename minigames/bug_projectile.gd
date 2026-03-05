extends RigidBody3D

@export var damage := 2
@export var dropped_bug_scene: PackedScene
@export var life_sec := 4.0

# --- SFX  ---
@export var sfx_throw: AudioStream
@export var sfx_hit_boss: AudioStream
@export var sfx_hit_world: AudioStream

var _has_damaged := false

func _ready() -> void:
	add_to_group("bug_projectiles")
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(life_sec).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

func fire_dir(dir: Vector3, speed: float) -> void:
	dir = dir.normalized()
	linear_velocity = dir * speed
	AudioHelper.play_one_shot_3d(get_tree(), sfx_throw, global_position)

func _drop_collectible_bug(kick_dir: Vector3 = Vector3.ZERO) -> void:
	if dropped_bug_scene == null:
		return

	var bug := dropped_bug_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(bug)
	bug.global_transform = global_transform

	if not bug.is_in_group("bugs"):
		bug.add_to_group("bugs")

	if kick_dir != Vector3.ZERO and bug is RigidBody3D:
		var rb := bug as RigidBody3D
		rb.linear_velocity = kick_dir.normalized() * 6.0 + Vector3.UP * 4.0

func _on_body_entered(body: Node) -> void:
	if not _has_damaged and (body.name == "HurtBox" or body.is_in_group("boss_hurtbox")):
		_has_damaged = true
		AudioHelper.play_one_shot_3d(get_tree(), sfx_hit_boss, global_position)

		if body.has_method("take_damage"):
			body.call("take_damage", damage)

		var away: Vector3 = global_position - (body as Node3D).global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = -global_transform.basis.z

		_drop_collectible_bug(away)
		queue_free()
		return

	if body.is_in_group("ground") or body.is_in_group("walls") or body.name == "Ground":
		AudioHelper.play_one_shot_3d(get_tree(), sfx_hit_world, global_position)
		_drop_collectible_bug()
		queue_free()
		return
