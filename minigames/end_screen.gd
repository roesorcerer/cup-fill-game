extends Control


@onready var box: Control = get_node_or_null("BoxContainer")
@onready var title: Label = get_node_or_null("BoxContainer/EndMessage")
@onready var subtitle: Label = get_node_or_null("BoxContainer/EndSubMessage")

@export var intro_fade_sec := 0.25
@export var intro_pop_sec := 0.25

@export var win_pulse_scale := 1.05
@export var win_pulse_sec := 0.12

@export var lose_shake_rot_deg := 5.0
@export var lose_shake_step_sec := 0.04
@export var lose_shake_steps := 8

var _base_modulate: Color
var _base_box_scale: Vector2 = Vector2.ONE
var _tween: Tween

func _ready() -> void:
	_base_modulate = modulate
	visible = false
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, 0.0)
	call_deferred("_update_pivots")

func _update_pivots() -> void:
	if box:
		box.pivot_offset = box.size * 0.5
		_base_box_scale = box.scale

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

func show_result(did_win: bool, custom_title: String = "", custom_subtitle: String = "") -> void:
	if title == null or subtitle == null:
		visible = true
		return

	if custom_title != "" and custom_subtitle != "":
		title.text = custom_title
		subtitle.text = custom_subtitle
	elif did_win:
		title.text = "Congratulations!"
		subtitle.text = "You defeated the spider and saved the ladybugs."
	else:
		title.text = "Game Over"
		subtitle.text = "The spider got you. You did not save the ladybugs."

	# Prep animation state.
	_kill_tween()
	visible = true
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, 0.0)

	if box:
		_update_pivots()
		box.rotation = 0.0
		box.scale = _base_box_scale * 0.85

	# Intro fade + pop.
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_color = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, 1.0)
	_tween.parallel().tween_property(self, "modulate", target_color, intro_fade_sec)
	if box:
		_tween.parallel().tween_property(box, "scale", _base_box_scale, intro_pop_sec)

	# Win pulse or lose shake. - Cant see rn
	if did_win:
		if box:
			_tween.tween_property(box, "scale", _base_box_scale * win_pulse_scale, win_pulse_sec)
			_tween.tween_property(box, "scale", _base_box_scale, win_pulse_sec)
			_tween.tween_property(box, "scale", _base_box_scale * win_pulse_scale, win_pulse_sec)
			_tween.tween_property(box, "scale", _base_box_scale, win_pulse_sec)
	else:
		if box:
			var r := deg_to_rad(lose_shake_rot_deg)
			for i in range(max(1, lose_shake_steps)):
				_tween.tween_property(box, "rotation", r if (i % 2 == 0) else -r, lose_shake_step_sec)
			_tween.tween_property(box, "rotation", 0.0, lose_shake_step_sec)
