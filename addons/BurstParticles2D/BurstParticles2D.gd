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

class Particle extends RefCounted:
	var rid: RID
	var texture: Texture2D
	var distance: float = 0
	var max_distance: float = 0
	var dir: float = 0
	var start_dir: float = 0
	var end_dir: float = 0
	var angle: float = 0
	var flip_angle: float = 0
	var max_angle: float = 0
	var material = null
	var scale_modifier := 1.0
	var x_scale := 1.0
	var y_scale := 1.0
	var alpha := 0.0
	var dead = false
	var color_offset := 0.0
	var t := 0.0
	var scale = 1.0
	var position: Vector2:
		get:
			return Vector2.from_angle(dir) * distance + offset
	var offset: Vector2 = Vector2()
	
	func kill():
		RenderingServer.free_rid(self.rid)
		dead = true

class BurstParticlesRng extends RandomNumberGenerator:
	func percent(percent: float) -> bool:
		return self.randi() % 100 < percent

	func exponential(param : float = 1.0) -> float:
		return ln(1.0 - randf())/(-param)

	func ln(arg : float) -> float:
		return log(arg)/log(exp(1))

@export_category("Particles")
@export var num_particles = 10
@export var lifetime = 1.0
@export_range(0.0, 1.0) var lifetime_randomness = 0.0
@export_range(0.0, 1.0) var preprocess_amount = 0.0
@export var reverse = false
@export var repeat = false
@export var free_when_finished = true
@export var autostart = true

@export_category("Texture")
@export var texture: Texture2D = preload("orb_small.png")
@export var image_scale = 1.0
@export_range(0.0, 1.0) var image_scale_randomness = 0.0
@export var gradient : GradientTexture1D
@export var blend_mode = BlendMode.Mix
@export_range(-360.0, 360.0, 0.5, "or_greater", "or_less") var angle_degrees = 0.0
@export_range(0.0, 1.0) var angle_randomness = 0.0
@export var randomly_flip_angle = false
@export_range(-1.0, 1.0) var color_offset_high = 0.0
@export_range(-1.0, 1.0) var color_offset_low = -1.0

# enable this if you are using a lot of particles and experience a stutter on instancing. 
# since instance uniforms aren't implemented in canvas_item shaders yet, each particle needs its own
# material. the drawback to enabling this is that every particle will have the same gradient color 
# offset, which looks less dynamic in most contexts. this will change as soon as instance uniforms 
# are implemented assuming they work when used directly with canvas items (not nodes).
@export var share_material = false

@export_category("Path")
# launch direction
@export var direction = Vector2(1, 0)
@export_range(-360.0, 360.0, 0.5, "or_greater", "or_less") var direction_rotation_degrees = 0.0
@export_range(0.0, 1.0) var direction_rotation_randomness = 0.0
@export var randomly_flip_rotation = false
@export_range(0.0, 4096, 0.001, "or_greater") var distance = 100.0
@export_range(0.0, 1.0) var distance_randomness = 0.0
@export var offset = Vector2(0, 0)
@export var global_offset = false

# point the sprite in the launch direction
@export var align_sprite_rotation = true
@export_range(0.0, 4096, 0.001, "or_greater", "or_less") var start_radius = 0.0

# width of the arc of possible launch angles
@export_range(0, 360) var spread_degrees = 360.0

# how closely particles tend to skew toward the center of the arc
@export_range(0.0, 100.0) var center_concentration = 0.0

# how many particles ignore the above parameter
@export_range(0.0, 100.0) var percent_force_uniform = 0.0

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

var particles: Array[Particle] = []
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

func _create_particle() -> Particle:
	var particle = Particle.new()
	var p_rid = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_add_texture_rect(p_rid, Rect2(texture.get_size() / 2, texture.get_size()), texture)
	particle.texture = texture
	particle.rid = p_rid
	RenderingServer.canvas_item_set_parent(particle.rid, get_canvas_item())
	if use_gradient_map:
		var p_material = _create_material() if !share_material else shared_material
		RenderingServer.canvas_item_set_material(particle.rid, p_material)
		particle.material = p_material
	return particle

func _ready():
	rng.randomize()
	if wait_for_siblings:
		return
	if autostart:
		burst()

func _create_material():
	var mat = ShaderMaterial.new()
	mat.shader = current_shader
	mat.set_shader_parameter("gradient", gradient)
	return mat

func _center_texture():
	return Vector2(-texture.get_width(), -texture.get_height())

func burst():
	if !finished:
		_finish()
	
	finished = false
	# init particles
	if share_material and use_gradient_map:
		shared_material = _create_material()
		
	for particle in particles:
		particle.kill()
	particles = []

	

	if texture:
		current_shader = [
			SHADER, 
			SHADER_ADD
		][blend_mode]

		for i in range(num_particles):
			var particle = _create_particle()
			particles.append(particle)

		# start burst
		tween = create_tween()
		tween.set_parallel(true)

		var update_method: Callable = _update_particle if !Engine.is_editor_hint() else _update_particle_editor

		var update_functions = _get_update_functions()
	
		for i in range(num_particles):
			var particle = particles[i]

			particle.texture = texture
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
			
			particle.max_distance = distance - rng.randf_range(0.0, distance_randomness * distance)

			if distance_falloff_curve and distance > 0:
				particle.max_distance *= (distance_falloff_curve.sample((abs(p_spread * 2) / deg_to_rad(spread_degrees))))
			particle.dir = p_dir
			particle.start_dir = p_dir
			particle.end_dir = p_dir + p_dir_rotation
			particle.scale_modifier = 1.0 - rng.randf_range(0.0, image_scale_randomness)
			particle.max_distance += start_radius
			particle.angle = p_angle
			particle.max_angle = p_angle
			particle.color_offset = color_offset_high
			particle.offset = offset
			
			
			if randomly_flip_angle and rng.randi() % 2 == 0:
				particle.angle *= -1
				particle.max_angle *= -1
			

			update_method.bind(particle, update_functions).call(preprocess_amount if !reverse else 1.0)
			var t_start = preprocess_amount if !reverse else 1.0
			var t_end = 1.0 if !reverse else preprocess_amount
			t = t_start
			tween.tween_property(self, "t", t_end, lifetime)
			tween.tween_method(update_method.bind(particle, update_functions), t_start, t_end, p_lifetime).set_delay(0.0 if !reverse else lifetime - p_lifetime)
			tween.tween_callback(particle.kill).set_delay(p_lifetime)
		
	var timer = get_tree().create_timer(lifetime, false)
	timer.timeout.connect(_finish)
	if wait_for_siblings:
		return
	if (repeat or Engine.is_editor_hint()):
		timer.timeout.connect(burst)
	elif free_when_finished:
		timer.timeout.connect(queue_free)

func _finish():
	if tween:
		tween.kill()
	finished_burst.emit()
	finished = true
	for particle in particles:
		particle.kill()

func _get_update_functions():
	# determine all the functions needed for tweening this particle and return them in an array.
	# this prevents redundant checking whether or not e.g. a curve is available for every parameter 
	# of every particle every frame.
	
	var update_functions: Array[Callable] = []

	if x_scale_curve:
		update_functions.append(func(t, particle): particle.x_scale = x_scale_curve.sample_baked(t))
	
	if y_scale_curve:
		update_functions.append(func(t, particle): particle.y_scale = y_scale_curve.sample_baked(t))
	
	if use_gradient_map:
		if color_offset_curve:
			if !share_material:
				update_functions.append(func(t, particle):
					RenderingServer.material_set_param(particle.material.get_rid(), "color_offset", lerp(color_offset_low, color_offset_high, color_offset_curve.sample_baked(t)))
				)
			else:
				update_functions.append(func(t, particle):
					RenderingServer.material_set_param(particle.material.get_rid(), "color_offset", lerp(color_offset_low, color_offset_high, color_offset_curve.sample_baked(self.t)))
				)
		else:
			if !share_material:
				update_functions.append(func(t, particle):
					RenderingServer.material_set_param(particle.material.get_rid(), "color_offset", lerp(color_offset_high, color_offset_low, t))
				)
			else:
				update_functions.append(func(t, particle):
					RenderingServer.material_set_param(particle.material.get_rid(), "color_offset", lerp(color_offset_high, color_offset_low, self.t))
				)

	if alpha_curve:
		update_functions.append(func(t, particle):
			particle.alpha = alpha_curve.sample_baked(t)
			RenderingServer.canvas_item_set_modulate(particle.rid, Color(1.0, 1.0, 1.0, particle.alpha))
		)

	if distance_curve:
		update_functions.append(func(t, particle):
			particle.distance = lerp(start_radius, particle.max_distance, distance_curve.sample_baked(t))
		)
	else:
		update_functions.append(func(t, particle):
			particle.distance = lerp(start_radius, particle.max_distance, t)
		)

	if scale_curve:
		update_functions.append(func(t, particle):
			particle.scale = Vector2(image_scale * particle.x_scale, image_scale * particle.y_scale) * particle.scale_modifier * (scale_curve.sample_baked(particle.t) if scale_curve != null else 1.0)
		)
	else:
		update_functions.append(func(t, particle):
			particle.scale = Vector2(image_scale * particle.x_scale, image_scale * particle.y_scale) * particle.scale_modifier
		)
	
	if angle_curve:
		update_functions.append(func(t, particle):
			particle.angle = particle.max_angle * angle_curve.sample_baked(t)
		)
	
	if offset_curve:
		if !global_offset:
			update_functions.append(func(t, particle):
				particle.offset = offset * offset_curve.sample_baked(t)
			)
		else:
			update_functions.append(func(t, particle):
				particle.offset = (offset * offset_curve.sample_baked(t)).rotated(-global_rotation)
			)
	else:
		if global_offset:
			update_functions.append(func(t, particle):
				particle.offset = offset.rotated(-global_rotation)
			)

	if rotation_curve:
		update_functions.append(func(t, particle):
			particle.dir = lerp(particle.start_dir, particle.end_dir, rotation_curve.sample_baked(t))
		)
	else:
		update_functions.append(func(t, particle):
			particle.dir = lerp(particle.start_dir, particle.end_dir, t)
		)

	if align_sprite_rotation:
		update_functions.append(func(_t, particle):
			RenderingServer.canvas_item_set_transform(particle.rid, Transform2D().translated(_center_texture()).rotated(particle.angle).scaled(particle.scale).translated(Vector2.RIGHT * particle.distance).rotated(particle.dir).translated(particle.offset))
		)
	else:
		update_functions.append(func(_t, particle):
			RenderingServer.canvas_item_set_transform(particle.rid, Transform2D().translated(_center_texture()).rotated(particle.angle).scaled(particle.scale).translated(particle.position))
		)
	return update_functions

func _update_particle(t: float, particle: Particle, update_functions: Array[Callable]):
	particle.t = t
	# havent extensively tested the performance benefit of doing it this way. it might actually be 
	# worse. branchless though!
	for function in update_functions:
		function.call(t, particle)

func _update_particle_editor(t: float, particle: Particle, update_functions: Array[Callable]):
	if particle.dead:
		return
	_update_particle(t, particle, update_functions)

func _exit_tree():
	for particle in particles:
		particle.kill()
