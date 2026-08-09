extends OmniLight3D

@export var flicker_speed := 1.8
@export var min_energy_scale := 0.6
@export var max_energy_scale := 1.0

var base_energy: float
var noise := FastNoiseLite.new()
var time := 0.0


func _ready() -> void:
	base_energy = light_energy
	noise.seed = randi()
	noise.frequency = 1.0


func _process(delta: float) -> void:
	time += delta * flicker_speed
	var n := (noise.get_noise_1d(time * 10.0) + 1.0) / 2.0
	light_energy = base_energy * lerp(min_energy_scale, max_energy_scale, n)
