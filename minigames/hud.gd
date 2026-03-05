extends Control

@onready var objective: Label = $ObjectiveLabel
@onready var controls: Label = $ControlsLabel
@onready var timer_label: Label = $TimerLabel
@onready var bugs_label: Label = $BugsLabel
@onready var player_hp: Range = $PlayerHP
@onready var player_hp_label: Label = get_node_or_null("PlayerHPLabel")
@onready var boss_hp: Range = $BossHP
@onready var boss_hp_label: Label = get_node_or_null("BossHPLabel")

func set_objective(t: String) -> void:
	if is_instance_valid(objective):
		objective.text = t

func set_controls(t: String) -> void:
	if is_instance_valid(controls):
		controls.text = t

func set_timer(seconds_left: float) -> void:
	if is_instance_valid(timer_label):
		timer_label.text = "Time Left Before Attack: %d" % int(ceil(seconds_left))

func set_bugs(count: int) -> void:
	if is_instance_valid(bugs_label):
		bugs_label.text = "LadyBugs Caught: %d" % count

func set_player_hp(norm_0_to_1: float) -> void:
	if is_instance_valid(player_hp):
		player_hp.value = clampf(norm_0_to_1, 0.0, 1.0) * player_hp.max_value

func set_boss_hp(norm_0_to_1: float) -> void:
	if is_instance_valid(boss_hp):
		boss_hp.value = clampf(norm_0_to_1, 0.0, 1.0) * boss_hp.max_value

func set_boss_visible(v: bool) -> void:
	if is_instance_valid(boss_hp):
		boss_hp.visible = v
	if is_instance_valid(boss_hp_label):
		boss_hp_label.visible = v

func set_info_mode(enabled: bool) -> void:
	var show_gameplay = !enabled

	
	if is_instance_valid(objective):
		objective.visible = true
	if is_instance_valid(controls):
		controls.visible = true

	if is_instance_valid(timer_label):
		timer_label.visible = show_gameplay

	if is_instance_valid(bugs_label):
		bugs_label.visible = show_gameplay


	if is_instance_valid(player_hp):
		player_hp.visible = show_gameplay
	if is_instance_valid(player_hp_label):
		player_hp_label.visible = show_gameplay

#Hide when boss stage is happening
	if is_instance_valid(boss_hp):
		boss_hp.visible = false
	if is_instance_valid(boss_hp_label):
		boss_hp_label.visible = false
