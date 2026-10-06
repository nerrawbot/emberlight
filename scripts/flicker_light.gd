extends OmniLight3D
## Broken lamp: stutters, cuts out and spits sparks. Dimmer when the grid is unpowered.

@export var base_energy := 2.2
@export var bulb_path: NodePath
@export var sparks_path: NodePath

var _bulb_mat: StandardMaterial3D
var _sparks: GPUParticles3D
var _t := 0.0
var _wait := 1.0
var _off := 0.0
var _burst := 0

func _ready() -> void:
	var bulb := get_node_or_null(bulb_path) as MeshInstance3D
	if bulb:
		_bulb_mat = bulb.material_override as StandardMaterial3D
	_sparks = get_node_or_null(sparks_path) as GPUParticles3D
	_wait = randf_range(0.5, 3.0)

func _process(delta: float) -> void:
	_t += delta
	var g := get_tree().get_first_node_in_group("power_grid")
	var scale_e := 1.0 if (g == null or g.powered) else 0.45
	if _off > 0.0:
		_off -= delta
		light_energy = 0.03
		if _bulb_mat:
			_bulb_mat.emission_energy_multiplier = 0.05
		return
	_wait -= delta
	if _wait <= 0.0:
		if _burst <= 0:
			_burst = randi_range(1, 5)
			if _sparks and randf() < 0.7:
				_sparks.restart()
		_burst -= 1
		_off = randf_range(0.03, 0.18)
		_wait = randf_range(0.04, 0.2) if _burst > 0 else randf_range(1.0, 5.0)
	var e := base_energy * scale_e * (0.88 + 0.12 * sin(_t * 31.0) * sin(_t * 4.3))
	light_energy = e
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 6.0 * e / base_energy
