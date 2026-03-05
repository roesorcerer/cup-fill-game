extends Node3D

enum Phase { MENU, COLLECT, BOSS, WIN, GAME_OVER, INFO }

@export var collect_duration_sec := 20.0

# --- Audio  ---
@export var sfx_boss_spawn: AudioStream
@export var sfx_win: AudioStream
@export var sfx_lose: AudioStream
@export var sfx_no_bugs: AudioStream

# --- Music  ---
@export var music_menu: AudioStream
@export var music_game_bugs: AudioStream
@export var music_boss: AudioStream
@export var music_game_over: AudioStream
@export var music_win: AudioStream

# How long to wait before showing the end screen
@export var end_screen_delay_sec := 1.0

@onready var player := $Player
@onready var spawner := $BugSpawner
@onready var boss := $SpiderBoss
@onready var collect_timer: Timer = $CollectTimer
@onready var music: AudioStreamPlayer = $Music
@onready var sfx_player: AudioStreamPlayer = $SFX

@onready var ui_menu := $CanvasLayer_UI/MainMenu
@onready var ui_hud := $CanvasLayer_UI/HUD
@onready var ui_end := $CanvasLayer_UI/EndScreen

var phase: Phase = Phase.MENU
var bugs_ammo: int = 0
var volume: int = -10

var _ending: bool = false

func _ready() -> void:
	await get_tree().process_frame

	if is_instance_valid(boss):
		boss.visible = false
	if is_instance_valid(ui_menu):
		ui_menu.visible = true
	if is_instance_valid(ui_hud):
		ui_hud.visible = false
	if is_instance_valid(ui_end):
		ui_end.visible = false

	collect_timer.one_shot = true
	collect_timer.timeout.connect(_on_collect_timer_timeout)

	player.bugs_collected.connect(_on_player_bugs_collected)
	player.player_died.connect(_on_player_died)
	player.hp_changed.connect(ui_hud.set_player_hp)

	boss.boss_died.connect(_on_boss_died)
	boss.hp_changed.connect(ui_hud.set_boss_hp)

	_set_phase(Phase.MENU)
	_play_music(music_menu)
	


func start_game() -> void:
	_ending = false
	bugs_ammo = 0
	ui_hud.set_bugs(bugs_ammo)
	ui_hud.set_player_hp(1.0)
	ui_hud.set_boss_visible(false)
	_play_music(music_game_bugs)
	_set_phase(Phase.COLLECT)
	spawner.start()
	collect_timer.start(collect_duration_sec)

func _physics_process(_delta: float) -> void:
	if phase == Phase.COLLECT:
		ui_hud.set_timer(collect_timer.time_left)
	elif phase == Phase.BOSS:
		ui_hud.set_timer(0)

func _on_collect_timer_timeout() -> void:
	spawner.stop()
	for b in get_tree().get_nodes_in_group("bugs"):
		b.queue_free()
	_start_boss_phase()

func _start_boss_phase() -> void:
	_set_phase(Phase.BOSS)
	_play_music(music_boss)

	var forward: Vector3 = -player.global_transform.basis.z
	boss.global_position = player.global_position + forward * 10.0

	boss.visible = true
	if sfx_boss_spawn:
		boss.sfx_player_attack = sfx_boss_spawn

	# No bugs collected = instant loss
	if bugs_ammo <= 0:
		ui_hud.set_boss_visible(true)
		ui_hud.set_boss_hp(1.0)
		ui_hud.set_objective("You collected 0 bugs... the spider got you!")
		_play_sfx(sfx_no_bugs if sfx_no_bugs != null else sfx_lose)
		player.play_death_animation()
		boss.start_fight(player)
		get_tree().create_timer(max(0.05, end_screen_delay_sec)).timeout.connect(_on_no_bugs_collected)
		return

	# Normal boss fight
	boss.start_fight(player)
	ui_hud.set_boss_visible(true)
	ui_hud.set_objective("Throw your collected bugs at the spider!")

	player.set_bug_ammo(bugs_ammo)
	player.set_can_shoot_bugs(true)
	player.set_boss_ref(boss)
	ui_hud.set_player_hp(1.0)
	ui_hud.set_boss_hp(1.0)

func _on_player_bugs_collected(count: int) -> void:
	bugs_ammo = count
	ui_hud.set_bugs(bugs_ammo)

func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	_set_phase(Phase.GAME_OVER)
	_play_music(music_game_over)
	_play_sfx(sfx_lose)
	player.play_death_animation()
	if is_instance_valid(ui_end):
		ui_end.show_result(false)

func _on_no_bugs_collected() -> void:
	if _ending:
		return
	_ending = true
	_set_phase(Phase.GAME_OVER)
	_play_music(music_game_over)
	_play_sfx(sfx_lose)
	if is_instance_valid(ui_end):
		ui_end.show_result(false, "Game Over", "You saved no lady bugs.")

func _on_boss_died() -> void:
	if _ending:
		return
	_ending = true
	_set_phase(Phase.WIN)
	AudioServer.set_bus_volume_db(0,volume)
	_play_music(music_win)
	_play_sfx(sfx_win) #duplication needs to be removed
	player.play_win_animation()
	if is_instance_valid(ui_end):
		ui_end.show_result(true)
	#if return_to_menu:
	#	music_win.stop


func _play_sfx(stream: AudioStream) -> void:
	if stream == null or sfx_player == null:
		return
	sfx_player.stream = stream
	sfx_player.play()

func _play_music(stream: AudioStream) -> void:
	if stream == null or music == null:
		return
	if music.playing:
		music.stop()
	music.stream = stream

	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	music.play()

func _set_phase(p: Phase) -> void:
	phase = p
	match phase:
		Phase.MENU:
			ui_menu.visible = true
			ui_hud.visible = false
			ui_hud.set_info_mode(false)
			ui_end.visible = false
			if is_instance_valid(boss):
				boss.visible = false
			spawner.stop()
		Phase.COLLECT:
			ui_menu.visible = false
			ui_hud.visible = true
			ui_hud.set_info_mode(false)
			ui_hud.set_objective("Collect bugs for 20 seconds!")
			ui_hud.set_controls("Right click: Turn the Camera \n E: Collect Bugs \n Left Click: Throw Collected LadyBug Friends to Defeat Spider")
			ui_end.visible = false
			if is_instance_valid(boss):
				boss.visible = false
		Phase.BOSS:
			ui_menu.visible = false
			ui_hud.visible = true
			ui_end.visible = false
		Phase.WIN, Phase.GAME_OVER:
			ui_menu.visible = false
			ui_hud.visible = false
			ui_end.visible = true
			spawner.stop()
		Phase.INFO:
			ui_menu.visible = true
			ui_hud.visible = true
			ui_hud.set_info_mode(true)
			ui_hud.set_objective("Hi, I am Rowan and I made a silly\n little game for a game jam. \nThis is my first game completed in Godot, \nand I want to thank you for \ntaking the time to play it")
			ui_hud.set_controls("Feel free to check out the repo or my research. \nThe repo has a Readme that will provide the inspo for this game and some links to rersources.")
			ui_end.visible = false

func end_game():
	get_tree().quit()

func info_button():
	_set_phase(Phase.INFO)

func _reset_state() -> void:
	if player:
		player.hp = player.max_hp
		player.hp_changed.emit(1.0)
		player.global_position = Vector3(0, 1, 0)
		player.set_physics_process(true)
		player.visual_pivot.rotation = Vector3.ZERO
		player.anim_target.rotation = Vector3.ZERO
		player.can_shoot_bugs = false
		player.bug_ammo = 0
		player.cup_is_open = false
		for child in player.bug_storage.get_children():
			child.queue_free()

	if is_instance_valid(boss):
		boss.visible = false
		boss.hp = boss.max_hp
		boss.scale = Vector3.ONE
		boss.rotation = Vector3.ZERO
		boss._dying = false
		boss._is_fighting = false
		boss.set_physics_process(false)
		boss.shoot_timer.stop()

	for node in get_tree().get_nodes_in_group("webs") \
			+ get_tree().get_nodes_in_group("bugs") \
			+ get_tree().get_nodes_in_group("bug_projectiles"):
		node.queue_free()

func replay_game() -> void:
	_reset_state()
	start_game()

func return_to_menu() -> void:
	_ending = false
	bugs_ammo = 0
	_reset_state()
	_set_phase(Phase.MENU)
	_play_music(music_menu)
