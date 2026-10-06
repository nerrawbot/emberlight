extends Light3D
## Light that brightens when the grid is powered (and dims / switches off when it is not).

@export var on_energy := 2.6
@export var off_energy := 1.0
@export var drift := 0.08   # slow unpowered wobble

var _t := randf() * 10.0
var _target := 0.0
var _powered := false

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	var g := get_tree().get_first_node_in_group("power_grid")
	if g:
		g.power_changed.connect(_on_power)
		_powered = g.powered
	_target = on_energy if _powered else off_energy
	light_energy = _target
	visible = _target > 0.001

func _on_power(on: bool) -> void:
	_powered = on
	var t := on_energy if on else off_energy
	visible = true
	var tw := create_tween()
	if on:   # stutter on
		tw.tween_property(self, "light_energy", t * 1.2, 0.07)
		tw.tween_property(self, "light_energy", 0.0, 0.06)
		tw.tween_property(self, "light_energy", t * 0.8, 0.1)
		tw.tween_property(self, "light_energy", 0.1, 0.05)
		tw.tween_property(self, "light_energy", t, 0.3)
	else:
		tw.tween_property(self, "light_energy", t, 0.5)
	tw.tween_callback(_settle.bind(t))

func _settle(t: float) -> void:
	_target = t
	visible = t > 0.001

func _process(delta: float) -> void:
	_t += delta
	if not _powered and _target > 0.0 and drift > 0.0:
		light_energy = _target * (1.0 + drift * sin(_t * 1.3) * sin(_t * 0.37))
