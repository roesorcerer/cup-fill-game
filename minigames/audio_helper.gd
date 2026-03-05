class_name AudioHelper

static func play_one_shot_3d(tree: SceneTree, stream: AudioStream, pos: Vector3) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Master"
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
