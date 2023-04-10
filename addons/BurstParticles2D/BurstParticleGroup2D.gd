@tool

extends Node2D

class_name BurstParticleGroup2D

@export var repeat = true
@export var free_when_finished = true
@export var autostart = true

var lifetime = 0
var finished = true

func _ready():
	child_entered_tree.connect(_on_child_entered_tree)
	for child in get_children():
		child.tree_exited.connect(_on_child_exited_tree)
		if child is BurstParticles2D:
			child.finished_burst.connect(_on_child_finished)
		update_children()
	if autostart or Engine.is_editor_hint():
		burst()

func _on_child_entered_tree(child: Node):
	child.tree_exited.connect(_on_child_exited_tree)
	if child is BurstParticles2D:
		child.finished_burst.connect(_on_child_finished)

func update_children():
	lifetime = 0
	for child in get_children():
		if child is BurstParticles2D:
			if child.lifetime > lifetime:
				lifetime = child.lifetime
			child.repeat = repeat
			child.free_when_finished = free_when_finished
			child.autostart = autostart

func burst():
	finished = false
	update_children()
	for child in get_children():
		if child is BurstParticles2D:
			child.burst()
	get_tree().create_timer(lifetime, false).timeout.connect(_finish)

func _on_child_exited_tree():
	if get_child_count() == 0 and !Engine.is_editor_hint():
		queue_free()

func _on_child_finished():
	for child in get_children():
		if child is BurstParticles2D:
			if !child.finished:
				return
	_finish()

func _finish():
	if finished:
		return
	finished = true
	if (repeat or Engine.is_editor_hint()):
		burst()
	elif free_when_finished:
		queue_free()
