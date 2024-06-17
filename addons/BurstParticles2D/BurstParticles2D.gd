@tool

extends Node2D

class_name BurstParticles2D

const SHADER = preload("BurstParticleGradientMap.gdshader")
const SHADER_ADD = preload("BurstParticleGradientMapAdd.gdshader")

signal finished_burst

enum BlendMode {
	Mix,
	Add,
}

#class Particle extends RefCounted:
var arr_rid: Array[RID] = []
var arr_texture: Array[Texture2D] = []
var arr_distance: Array[float] = []
var arr_max_distance: Array[float] = []
var arr_dir: Array[float] = []
var arr_start_dir: Array[float] = []
var arr_end_dir: Array[float] = []
var arr_angle: Array[float] = []
var arr_flip_angle: Array[float] = []
var arr_max_angle: Array[float] = []
var arr_material: Array[ShaderMaterial] = []
var arr_scale_modifier :Array[float] = []
var arr_x_scale :Array[float] = []
var arr_y_scale :Array[float] = []
var arr_alpha :Array[float] = []
var arr_dead :Array[float] = []
var arr_color_offset :Array[float] = []
var arr_t : Array[float] = []
var arr_scale : Array[Vector2] = []
var arr_offset :Array[Vector2] = []

func _new_particle():
	var id = current_particle_id 
	current_particle_id = (current_particle_id + 1) % num_particles
	#arr_rid[id] = null
	#arr_texture[id] = null
	#arr_distance[id] = null
	arr_max_distance[id] = 0
	arr_dir[id] = 0
	arr_start_dir[id] = 0
	arr_end_dir[id] = 0
	arr_angle[id] = 0
	arr_flip_angle[id] = 0
	arr_max_angle[id] = 0
	#arr_material[id] = null
	arr_scale_modifier[id] = 1.0
	arr_x_scale[id] = 1.0
	arr_y_scale[id] = 1.0
	arr_alpha[id] = 0.0
	arr_dead[id] = false
	arr_color_offset[id] = 0.0
	arr_t[id] = 0.0
	arr_scale[id] = Vector2()
	#arr_position[id] = null
	arr_offset[id] = Vector2()
	return id


func _resize_arrays() -> void:
	arr_rid.resize(num_particles)
	arr_texture.resize(num_particles)
	arr_distance.resize(num_particles)
	arr_max_distance.resize(num_particles)
	arr_dir.resize(num_particles)
	arr_start_dir.resize(num_particles)
	arr_end_dir.resize(num_particles)
	arr_angle.resize(num_particles)
	arr_flip_angle.resize(num_particles)
	arr_max_angle.resize(num_particles)
	arr_material.resize(num_particles)
	arr_scale_modifier.resize(num_particles)
	arr_x_scale.resize(num_particles)
	arr_y_scale.resize(num_particles)
	arr_alpha.resize(num_particles)
	arr_dead.resize(num_particles)
	arr_color_offset.resize(num_particles)
	arr_t.resize(num_particles)
	arr_scale.resize(num_particles)
	arr_offset.resize(num_particles)

func _get_particle_position(id: int) -> Vector2:
		return Vector2.from_angle(arr_dir[id]) * arr_distance[id] + arr_offset[id]

func _kill_particle(id: int) -> void:
	RenderingServer.free_rid(arr_rid[id])
	arr_dead[id] = true

class BurstParticlesRng extends RandomNumberGenerator:
	func percent(percent: float) -> bool:
		return self.randi() % 100 < percent

	func exponential(param : float = 1.0) -> float:
		return ln(1.0 - randf())/(-param)

	func ln(arg : float) -> float:
		return log(arg)/log(exp(1))

@export_category("Particles")
@export var num_particles := 10:
	set(value):
		kill()
		num_particles = value
		_resize_arrays()
@export var lifetime := 1.0
@export_range(0.0, 1.0) var lifetime_randomness := 0.0
@export_range(0.0, 1.0) var preprocess_amount := 0.0
@export var reverse := false
@export var repeat := false
@export var free_when_finished := true
@export var autostart := true

@export_category("Texture")
@export var texture: Texture2D = preload("orb_small.png")
@export var image_scale := 1.0
@export_range(0.0, 1.0) var image_scale_randomness := 0.0
@export var gradient : GradientTexture1D
@export var blend_mode := BlendMode.Mix
@export_range(-360.0, 360.0, 0.5, "or_greater", "or_less") var angle_degrees := 0.0
@export_range(0.0, 1.0) var angle_randomness := 0.0
@export var randomly_flip_angle := false
@export_range(-1.0, 1.0) var color_offset_high := 0.0
@export_range(-1.0, 1.0) var color_offset_low := -1.0

# enable this if you are using a lot of particles and experience a stutter on instancing. 
# since instance uniforms aren't implemented in canvas_item shaders yet, each particle needs its own
# material. the drawback to enabling this is that every particle will have the same gradient color 
# offset, which looks less dynamic in most contexts. this will change as soon as instance uniforms 
# are implemented assuming they work when used directly with canvas items (not nodes).
@export var share_material := false:
	set(value):
		share_material = value
		arr_material.clear()
		arr_material.resize(num_particles)
		kill()

@export_category("Path")
# launch direction
@export var direction := Vector2(1, 0)
@export_range(-360.0, 360.0, 0.5, "or_greater", "or_less") var direction_rotation_degrees := 0.0
@export_range(0.0, 1.0) var direction_rotation_randomness := 0.0
@export var randomly_flip_rotation := false
@export_range(0.0, 4096, 0.001, "or_greater") var distance := 100.0
@export_range(0.0, 1.0) var distance_randomness := 0.0
@export var offset := Vector2(0, 0)
@export var global_offset := false

# point the sprite in the launch direction
@export var align_sprite_rotation := true
@export_range(0.0, 4096, 0.001, "or_greater", "or_less") var start_radius := 0.0

# width of the arc of possible launch angles
@export_range(0, 360) var spread_degrees := 360.0

# how closely particles tend to skew toward the center of the arc
@export_range(0.0, 100.0) var center_concentration := 0.0

# how many particles ignore the above parameter
@export_range(0.0, 100.0) var percent_force_uniform := 0.0

# change how far particles will go depending on their angular distance from 
# the launch direction
@export var distance_falloff_curve : Curve = null 

@export_category("Tween Curves")
@export var distance_curve : Curve = null
@export var rotation_curve : Curve = null
@export var offset_curve: Curve = null
@export var angle_curve: Curve = null
@export var scale_curve : Curve = null
@export var x_scale_curve : Curve = null
@export var y_scale_curve : Curve = null
@export var color_offset_curve : Curve = null
@export var alpha_curve: Curve = null

var current_particle_id: int = 0

var rng = BurstParticlesRng.new()
var shared_material = null
var current_shader = SHADER
var finished = true
var t = 0.0 # time elapsed
var tween
var use_gradient_map:
	get:
		return gradient != null

@onready var wait_for_siblings = get_parent() is BurstParticleGroup2D

func _create_particle() -> int:
	var p_id: int = _new_particle()
	var p_rid := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_add_texture_rect(p_rid, Rect2(texture.get_size() / 2, texture.get_size()), texture)
	arr_texture[p_id] = texture
	arr_rid[p_id] = p_rid
	RenderingServer.canvas_item_set_parent(p_rid, get_canvas_item())
	if use_gradient_map:
		var p_material = (_create_material() if arr_material[p_id] == null else arr_material[p_id]) if !share_material else shared_material
		RenderingServer.canvas_item_set_material(p_rid, p_material)
		arr_material[p_id] = p_material

	return p_id

func _ready() -> void:
	_resize_arrays()
	rng.randomize()
	if wait_for_siblings:
		return
	if autostart:
		burst()
	if !Engine.is_editor_hint():
		set_process.call_deferred(false)

func _process(delta: float) -> void:
	pass

func _create_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = current_shader
	mat.set_shader_parameter("gradient", gradient)
	return mat

func _center_texture() -> Vector2:
	return Vector2(-texture.get_width(), -texture.get_height())


func burst() -> void:
	current_particle_id = 0
	if arr_rid.size() != num_particles:
		_resize_arrays()

	if !finished:
		_finish()
	
	finished = false
	# init particles

	if share_material and use_gradient_map:
		shared_material = _create_material()

	kill()

	if texture:
		current_shader = [
			SHADER, 
			SHADER_ADD
		][blend_mode]

		for i in range(num_particles):
			_create_particle()


		# start burst
		tween = create_tween()
		tween.set_parallel(true)

		var update_method: Callable = _update_particle if !Engine.is_editor_hint() else _update_particle_editor

		var update_functions = _get_update_functions()
	
		for p_id in range(num_particles):
			
			arr_texture[p_id] = texture
			var p_dir: float = direction.angle()
			var p_spread: float = deg_to_rad(rng.randf_range(-spread_degrees/2.0, spread_degrees/2.0))

			if center_concentration > 0 and !rng.percent(percent_force_uniform):
				p_spread *= rng.exponential(center_concentration)
			p_dir += p_spread

			var p_lifetime: float = lifetime - rng.randf_range(0.0, lifetime_randomness * lifetime) - lifetime * preprocess_amount
			var p_angle: float = deg_to_rad(angle_degrees - rng.randf_range(0.0, angle_randomness * angle_degrees))
			var p_dir_rotation: float = deg_to_rad(direction_rotation_degrees - rng.randf_range(0.0, direction_rotation_randomness * direction_rotation_degrees))

			if randomly_flip_rotation and rng.randi() % 2 == 0:
				p_dir_rotation *= -1
			
			arr_max_distance[p_id] = distance - rng.randf_range(0.0, distance_randomness * distance)

			if distance_falloff_curve and distance > 0:
				arr_max_distance[p_id] *= (distance_falloff_curve.sample((abs(p_spread * 2) / deg_to_rad(spread_degrees))))
			arr_dir[p_id] = p_dir
			arr_start_dir[p_id] = p_dir
			arr_end_dir[p_id] = p_dir + p_dir_rotation
			arr_scale_modifier[p_id] = 1.0 - rng.randf_range(0.0, image_scale_randomness)
			arr_max_distance[p_id] += start_radius
			arr_angle[p_id] = p_angle
			arr_max_angle[p_id] = p_angle
			arr_color_offset[p_id] = color_offset_high
			arr_offset[p_id] = offset
			
			if randomly_flip_angle and rng.randi() % 2 == 0:
				arr_angle[p_id] *= -1
				arr_max_angle[p_id] *= -1

			update_method.bind(p_id, update_functions).call(preprocess_amount if !reverse else 1.0)
			var t_start = preprocess_amount if !reverse else 1.0
			var t_end = 1.0 if !reverse else preprocess_amount
			t = t_start
			tween.tween_property(self, "t", t_end, lifetime)
			tween.tween_method(update_method.bind(p_id, update_functions), t_start, t_end, p_lifetime).set_delay(0.0 if !reverse else lifetime - p_lifetime)
			tween.tween_callback(_kill_particle.bind(p_id)).set_delay(p_lifetime)
		
	var timer = get_tree().create_timer(lifetime, false)
	timer.timeout.connect(_finish)
	if wait_for_siblings:
		return
	if (repeat or Engine.is_editor_hint()):
		timer.timeout.connect(burst)
	elif free_when_finished:
		timer.timeout.connect(queue_free)

func _finish() -> void:
	if tween:
		tween.kill()
	finished_burst.emit()
	finished = true
	kill()

func _get_update_functions() -> Array[Callable]:
	# determine all the functions needed for tweening this particle and return them in an array.
	# this prevents redundant checking whether or not e.g. a curve is available for every parameter 
	# of every particle every frame.
	
	var update_functions: Array[Callable] = []

	if x_scale_curve:
		update_functions.append(func(t: float, p_id: int) -> void: arr_x_scale[p_id] = x_scale_curve.sample_baked(t))
	
	if y_scale_curve:
		update_functions.append(func(t: float, p_id: int) -> void: arr_y_scale[p_id] = y_scale_curve.sample_baked(t))
	
	if use_gradient_map:
		if color_offset_curve:
			if !share_material:
				update_functions.append(func(t: float, p_id: int) -> void:
					RenderingServer.material_set_param(arr_material[p_id].get_rid(), "color_offset", lerp(color_offset_low, color_offset_high, color_offset_curve.sample_baked(t)))
				)
			else:
				update_functions.append(func(t: float, p_id: int) -> void:
					RenderingServer.material_set_param(arr_material[p_id].get_rid(), "color_offset", lerp(color_offset_low, color_offset_high, color_offset_curve.sample_baked(self.t)))
				)
		else:
			if !share_material:
				update_functions.append(func(t: float, p_id: int) -> void:
					RenderingServer.material_set_param(arr_material[p_id].get_rid(), "color_offset", lerp(color_offset_high, color_offset_low, t))
				)
			else:
				update_functions.append(func(t: float, p_id: int) -> void:
					RenderingServer.material_set_param(arr_material[p_id].get_rid(), "color_offset", lerp(color_offset_high, color_offset_low, self.t))
				)

	if alpha_curve:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_alpha[p_id] = alpha_curve.sample_baked(t)
			RenderingServer.canvas_item_set_modulate(arr_rid[p_id], Color(1.0, 1.0, 1.0, arr_alpha[p_id]))
		)

	if distance_curve:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_distance[p_id] = lerp(start_radius, arr_max_distance[p_id], distance_curve.sample_baked(t))
		)
	else:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_distance[p_id] = lerp(start_radius, arr_max_distance[p_id], t)
		)

	if scale_curve:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_scale[p_id] = Vector2(image_scale * arr_x_scale[p_id], image_scale * arr_y_scale[p_id]) * arr_scale_modifier[p_id] * (scale_curve.sample_baked(arr_t[p_id]) if scale_curve != null else 1.0)
		)
	else:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_scale[p_id] = Vector2(image_scale * arr_x_scale[p_id], image_scale * arr_y_scale[p_id]) * arr_scale_modifier[p_id]
		)
	
	if angle_curve:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_angle[p_id] = arr_max_angle[p_id] * angle_curve.sample_baked(t)
		)
	
	if offset_curve:
		if !global_offset:
			update_functions.append(func(t: float, p_id: int) -> void:
				arr_offset[p_id] = offset * offset_curve.sample_baked(t)
			)
		else:
			update_functions.append(func(t: float, p_id: int) -> void:
				arr_offset[p_id] = (offset * offset_curve.sample_baked(t)).rotated(-global_rotation)
			)
	else:
		if global_offset:
			update_functions.append(func(t: float, p_id: int) -> void:
				arr_offset[p_id] = offset.rotated(-global_rotation)
			)

	if rotation_curve:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_dir[p_id] = lerp(arr_start_dir[p_id], arr_end_dir[p_id], rotation_curve.sample_baked(t))
		)
	else:
		update_functions.append(func(t: float, p_id: int) -> void:
			arr_dir[p_id] = lerp(arr_start_dir[p_id], arr_end_dir[p_id], t)
		)

	if align_sprite_rotation:
		update_functions.append(func(t: float, p_id: int) -> void:
			RenderingServer.canvas_item_set_transform(arr_rid[p_id], Transform2D().translated(_center_texture()).rotated(arr_angle[p_id]).scaled(arr_scale[p_id]).translated(Vector2.RIGHT * arr_distance[p_id]).rotated(arr_dir[p_id]).translated(arr_offset[p_id]))
		)
	else:
		update_functions.append(func(t: float, p_id: int) -> void:
			RenderingServer.canvas_item_set_transform(arr_rid[p_id], Transform2D().translated(_center_texture()).rotated(arr_angle[p_id]).scaled(arr_scale[p_id]).translated(_get_particle_position(p_id)))
		)
	return update_functions

func _update_particle(t: float, particle_id: int, update_functions: Array[Callable]) -> void:
	arr_t[particle_id] = t
	# havent extensively tested the performance benefit of doing it this way. it might actually be 
	# worse. branchless though!
	for function in update_functions:
		function.call(t, particle_id)

func _update_particle_editor(t: float, particle_id: int, update_functions: Array[Callable]) -> void:
	if particle_id >= num_particles or arr_dead[particle_id]:
		return
	_update_particle(t, particle_id, update_functions)

func _exit_tree() -> void:
	kill()

func kill():
	for i in num_particles:
		if i < arr_rid.size():
			_kill_particle(i)

