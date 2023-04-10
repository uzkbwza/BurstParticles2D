@tool

extends Node2D

class_name BurstParticles2D

const SHADER = preload("./BurstParticleGradientMap.gdshader")

@export_category("Particles")
@export var num_particles = 10
@export var lifetime = 1.0
@export_range(0.0, 1.0) var lifetime_randomness = 0.0
@export_range(0.0, 1.0) var preprocess_amount = 0.0
@export var reverse = false
@export var repeat = false

@export_category("Texture")
@export var texture: Texture2D
@export var use_gradient_map = true
@export var image_scale = 1.0
@export var gradient : GradientTexture1D
@export_range(0.0, 1.0) var image_scale_randomness = 0.0

@export_category("Path")
# launch direction
@export var direction = Vector2(1, 0)
@export_range(0.0, 4096, 0.001, "or_greater") var distance = 100.0
@export_range(0.0, 1.0) var distance_randomness = 0.0
@export var offset = Vector2(0, 0)
@export var global_offset = false
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
@export var offset_curve: Curve = null
@export var scale_curve : Curve = null
@export var x_scale_curve : Curve = null
@export var y_scale_curve : Curve = null
@export var color_offset_curve : Curve = null
@export var alpha_curve: Curve = null

var particles: Array[Particle] = []
var rng = BetterRng.new()

class Particle extends RefCounted:
	var rid: RID
	var texture: Texture2D
	var distance: float = 0
	var max_distance: float = 0
	var dir: float = 0
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
			return Utils.ang2vec(dir) * distance
	var offset: Vector2 = Vector2()

	func init(texture):
		var p_rid = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_add_texture_rect(p_rid, Rect2(texture.get_size() / 2, texture.get_size()), texture)
		self.texture = texture
		self.rid = p_rid
	
	func clear():
		RenderingServer.free_rid(self.rid)
		dead = true

func _ready():
	rng.randomize()
	burst()

func init():
	for particle in particles:
		particle.clear()
	particles = []

	for i in range(num_particles):
		var particle = create_particle()
		particles.append(particle)
	pass

func center_texture():
	return Vector2(-texture.get_width(), -texture.get_height())

func create_particle() -> Particle:
	var particle = Particle.new()
	particle.init(texture)
	var p_material = ShaderMaterial.new()
	p_material.shader = SHADER
	p_material.set_shader_parameter("gradient", gradient)
	RenderingServer.canvas_item_set_parent(particle.rid, get_canvas_item())
	RenderingServer.canvas_item_set_material(particle.rid, p_material)
	particle.material = p_material
	return particle

func burst():
	init()

	var tween = create_tween()
	tween.set_parallel(true)

	var update_method: Callable = update_particle if !Engine.is_editor_hint() else update_particle_editor
	
	for i in range(num_particles):
		var particle = particles[i]

		particle.texture = texture
		var p_dir: float = direction.angle()
		var p_spread: float = deg_to_rad(rng.randf_range(-spread_degrees/2.0, spread_degrees/2.0))
		if center_concentration > 0 and !rng.percent(percent_force_uniform):
			p_spread *= rng.exponential(center_concentration)
		p_dir += p_spread
		var p_lifetime: float = lifetime - rng.randf_range(0.0, lifetime_randomness * lifetime) - lifetime * preprocess_amount
		particle.max_distance = distance - rng.randf_range(0.0, distance_randomness * distance)

		if distance_falloff_curve:
			particle.max_distance *= (distance_falloff_curve.sample((abs(p_spread * 2) / deg_to_rad(spread_degrees))))
		particle.dir = p_dir
		particle.scale_modifier = 1.0 - rng.randf_range(0.0, image_scale_randomness)
		particle.max_distance += start_radius

		
		var update_functions: Array[Callable] = []
		
		# add curve functions as needed
		if x_scale_curve:
			update_functions.append(func(t, particle): particle.x_scale = x_scale_curve.sample_baked(t))
		
		if y_scale_curve:
			update_functions.append(func(t, particle): particle.y_scale = y_scale_curve.sample_baked(t))
		
		if color_offset_curve:
			update_functions.append(func(t, particle):
				particle.color_offset = color_offset_curve.sample_baked(t)
				RenderingServer.material_set_param(particle.material.get_rid(), "color_offset", particle.color_offset)
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
			
			particle.offset = offset
			if global_offset:
				update_functions.append(func(t, particle):
					particle.offset = offset.rotated(-global_rotation)
				)

		update_method.bind(particle, update_functions).call(preprocess_amount if !reverse else 1.0)
		tween.tween_method(update_method.bind(particle, update_functions), preprocess_amount if !reverse else 1.0, 1.0 if !reverse else preprocess_amount, p_lifetime).set_delay(0.0 if !reverse else lifetime - p_lifetime)
		tween.tween_callback(particle.clear).set_delay(p_lifetime)

	get_tree().create_timer(lifetime, false).timeout.connect(burst if Engine.is_editor_hint() or repeat else queue_free)

func update_particle(t: float, particle: Particle, update_functions: Array[Callable]):
	particle.t = t
	
	# havent extensively tested the performance benefit of doing it this way.
	# it might actually be worse. branchless though!
	for function in update_functions:
		function.call(t, particle)

	RenderingServer.canvas_item_set_transform(particle.rid, Transform2D().translated(center_texture()).scaled(particle.scale).translated(Vector2.RIGHT * particle.distance).rotated(particle.dir).translated(particle.offset))

func update_particle_editor(t: float, particle: Particle, update_functions: Array[Callable]):
	if particle.dead:
		return
	update_particle(t, particle, update_functions)

func _exit_tree():
	for particle in particles:
		particle.clear()
