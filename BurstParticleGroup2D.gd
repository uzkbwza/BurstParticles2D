extends Node2D

class_name BurstParticleGroup2D

func _ready():
	for child in get_children():
		child.tree_exited.connect(on_child_tree_exited)

func on_child_tree_exited():
	if get_child_count() == 0:
		queue_free()
