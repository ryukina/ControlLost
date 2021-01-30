extends Node

class_name GameManager

var initialized = false
var animating = {}
var terrains = {}
var blocks = {}
var terrains_map = {}
var blocks_map = {}
var steps = []
var last_processed = -1
var stage = null


func _init():
	assert(Global.current_game == null)
	Global.current_game = self


func end():
	stage.end()
	assert(Global.current_game == self)
	Global.current_game = null


func all_positions():
	return terrains_map.keys()


func in_map(pos: Vector2):
	return pos in terrains_map


func get_terrain(pos: Vector2):
	return terrains_map[pos]


func get_block(pos: Vector2):
	if pos in blocks_map:
		return blocks_map[pos]
	return null


var available_directions = []

func check_movable(block, i):
	var direction = Triangle.ID_DIRECTIONS[i]
	for pos_id in block.pos_ids:
		for next in Triangle.get_pathway(pos_id + block.moved_pos, direction):
			if not in_map(next):
				return false
			var existing_block = get_block(next)
			if existing_block != null and existing_block != block:
				return false
			var terrain = get_terrain(next)
			if terrain != null and terrain.will_block(block):
				return false
	return true


func update_directions():
	dragging_direction = -1
	available_directions = []
	for di in range(6):
		if check_movable(dragging_block, di):
			available_directions.append(di)


const DRAGGING_THRESHOLD = 200
var dragging_block = null
var dragging_start = Vector2()
var dragging_direction = -3
var dragging_block_position = Vector2()
func drag(block):
	if dragging_block != null or not block.is_draggable:
		return
	block.is_dragging = true
	dragging_block = block
	dragging_start = block.get_global_mouse_position()
	dragging_block_position = block.position
	update_directions()


func cancel_drag():
	if dragging_block == null:
		return
	if dragging_direction >= 0:
		var moved = dragging_block.position - dragging_block_position
		var moved_length = moved.length()
		if moved_length < Triangle.SideLength / 2:
			dragging_block.move_to(dragging_block_position)
		else:
			complete_move(dragging_block, 
				dragging_direction if moved.dot(Triangle.DIRECTIONS[dragging_direction]) >= 0 \
				else Triangle.get_opposite(dragging_direction)
			)
	dragging_block.is_dragging = false
	dragging_block = null
	dragging_start = Vector2()
	dragging_direction = -3
	available_directions = []


func complete_move(block, di: int):
	for pos_id in block.pos_ids:
		blocks_map.erase(pos_id + block.moved_pos)
	block.moved_pos += Triangle.ID_DIRECTIONS[di]
	for pos_id in block.pos_ids:
		blocks_map[pos_id + block.moved_pos] = block
	var to_move = Triangle.DIRECTIONS[di] * Triangle.SideLength
	block.move_to(dragging_block_position + to_move)
	dragging_block_position = dragging_block_position + to_move
	dragging_start += to_move
	steps.append([{
		"type": "move",
		"block": block,
		"direction": di
	}])
	print(steps[steps.size() - 1])
	update_directions()


func process_dragging():
	var block = dragging_block
	if not Input.is_mouse_button_pressed(BUTTON_LEFT):
		cancel_drag()
		return
	var mp = block.get_global_mouse_position() - dragging_start
	var mp_r2 = mp.length_squared()
	if mp_r2 < 20 and dragging_direction >= 0:
		dragging_direction = -1
	if dragging_direction == -1 and mp_r2 >= DRAGGING_THRESHOLD:
		var di = Triangle.get_direction(mp)
		if di in available_directions:
			dragging_direction = di
		else:
			var opposite = Triangle.get_opposite(di)
			if opposite in available_directions:
				dragging_direction = di
			else:
				dragging_direction = -2
	if dragging_direction >= 0:
		var direction = Triangle.DIRECTIONS[dragging_direction]
		var to_move = mp.dot(direction)
		var redrag = false
		if to_move <= 0:
			var opposite = Triangle.get_opposite(dragging_direction)
			if opposite in available_directions:
				if to_move <= -Triangle.SideLength:
					complete_move(block, opposite)
					to_move = 0.0
			else:
				to_move = 0.0
		elif dragging_direction in available_directions:
			if to_move >= Triangle.SideLength:
				complete_move(block, dragging_direction)
				to_move = 0.0
		else:
			to_move = 0.0
		if to_move != 0.0:
			block.position = dragging_block_position + to_move * direction


func is_busy():
	return not initialized or animating.size() > 0 or is_processing


var is_processing = false
func process_events():
	if is_processing or last_processed == steps.size():
		return
	is_processing = true
	for block in blocks:
		for terrain in terrains:
			if terrain.check_interact(block):
				cancel_drag()
				terrain.interact(block)
				var to_break = yield(terrain, "interacted")
				if to_break:
					return
	last_processed = steps.size()
	is_processing = false


func _process(delta):
	if is_busy():
		return
	if dragging_block != null:
		process_dragging()
	if not is_processing:
		process_events()


var initial_cache = {}

func initialize():
	if initialized:
		return
	# TODO: Intialize initial_cache
	print("Initialized!")
	initialized = true


func restart():
	if is_busy():
		return
	print("Restarting...")
	initialized = false
	steps = []
	blocks_map = {}
	for block in blocks:
		block.moved_pos = Vector2.ZERO
		block.position = block.original_position
		for pos_id in block.pos_ids:
			blocks_map[pos_id] = block
	initialize()


func go_back():
	if is_busy():
		return
	if steps.size() == 0:
		# No step to go back
		return
	var last_step = steps.pop_back()
	last_processed -= 1
	for each in last_step:
		match each["type"]:
			"move":
				var block = each["block"]
				var direction = each["direction"]
				block.move_with_logics(
					Triangle.get_opposite(direction), 5
				)