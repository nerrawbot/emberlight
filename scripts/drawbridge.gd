extends AnimatableBody3D
## Hydraulic drawbridge. The node sits on the hinge; the deck extends along local -X.
## Raised it stands upright (and blocks the gap), lowered it lies flat. Lowered by bridge_valve.gd.

signal lowered

@export var raised := true
@export var lower_time := 4.5
@export var raised_angle := -90.0   # degrees about local Z (negative lifts the -X end)

func _ready() -> void:
	rotation.z = deg_to_rad(raised_angle) if raised else 0.0

func lower() -> void:
	if not raised:
		return
	raised = false
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(0.6)                      # the ram takes a moment to bleed off
	tw.tween_property(self, "rotation:z", deg_to_rad(raised_angle * 0.92), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation:z", 0.0, lower_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:z", deg_to_rad(1.5), 0.12)    # thud + settle
	tw.tween_property(self, "rotation:z", 0.0, 0.25)
	tw.tween_callback(func(): lowered.emit())
