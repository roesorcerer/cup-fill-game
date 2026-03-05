extends Area3D

@export var damage := 1
@export var life_sec := 3.0

# --- SFX (assign in Inspector) ---
@export var sfx_hit: AudioStream

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("webs")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life_sec).timeout.connect(queue_free)

func fire_at(target_pos: Vector3, speed: float) -> void:
	var dir = (target_pos - global_position).normalized()
	velocity = dir * speed

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	AudioHelper.play_one_shot_3d(get_tree(), sfx_hit, global_position)
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
