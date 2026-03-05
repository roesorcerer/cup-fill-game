extends StaticBody3D

@onready var boss := get_parent()

func take_damage(amount: int):
	if boss and boss.has_method("take_damage"):
		boss.take_damage(amount)
