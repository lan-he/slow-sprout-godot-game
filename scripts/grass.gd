extends Node2D
@onready var area_2d: Area2D = $Area2D
const GTASS_EFFECT = preload("res://effects/grass.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.area_entered.connect(_on_area_2d_area_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_2d_area_entered(area: Area2D) -> void:
	var grass_effect_instantiate = GTASS_EFFECT.instantiate()
	get_tree().current_scene.add_child(grass_effect_instantiate)
	grass_effect_instantiate.global_position = global_position
	queue_free()
	pass
