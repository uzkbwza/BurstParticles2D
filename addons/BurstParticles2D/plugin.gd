@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("BurstParticles2D", "Node2D", preload("BurstParticles2D.gd"), preload("icon.svg"))
	add_custom_type("BurstParticleGroup2D", "Node2D", preload("BurstParticleGroup2D.gd"), preload("icon_group.svg"))
