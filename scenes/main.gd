extends Node2D

const Stage = preload("res://stages/stage.gd")
var current_stage: Stage = null


func start(stage_name):
	var stage = load("res://stages/%s.tscn" % stage_name)
	if current_stage != null:
		current_stage.queue_free()
	current_stage = stage.instance()
	add_child(current_stage)


func _ready():
	var stage_name = "stage-1"  # for debugging
	if Global.loading_stage != null:
		stage_name = Global.loading_stage
		Global.loading_stage = null
	start(stage_name)
