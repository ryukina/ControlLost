extends Node
class_name GameManager

signal step_completed(step)
signal direction_changed(direction)
signal game_over

var initialized = false
var animating = {}
var terrains = []
var blocks = []
var terrains_map = {}
var blocks_map = {}
var steps = []
var last_processed = -1
var stage = null
var current_direction = -1 setget set_current_direction


func _ready():
	assert(Global.current_game == null)
	Global.current_game = self


func end():
	assert(Global.current_game == self)
	Global.current_game = null
	stage.end()
	emit_signal("game_over")


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


func set_current_direction(value: int):
	if current_direction != value:
		current_direction = value
		emit_signal("direction_changed", value)


var available_directions = []

func check_movable(block, i):
	var direction = Triangle.ID_DIRECTIONS[i]
	var ids = block.get_pos_ids()
	var allowed_blocks = block.get_all_blocks()
	for pos_id in ids:
		for next in Triangle.get_pathway(pos_id, direction):
			if not in_map(next):
				return false
			var existing_block = get_block(next)
			if existing_block != null and not (existing_block in allowed_blocks):
				return false
			var terrain = get_terrain(next)
			if terrain != null and terrain.will_block(block):
				return false
	return true


func update_directions():
	if dragging_block == null:
		return
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
	if block.is_player():
		SFX.play(SFX.PLAYER_SELECT)
	else:
		SFX.play(SFX.STONE_MOVE_START)
		SFX.play(SFX.STONE_SELECT)
	block.is_dragging = true
	dragging_block = block
	dragging_start = block.get_global_mouse_position()
	dragging_block_position = block.position
	update_directions()


func cancel_drag(force_back = false):
	if dragging_block == null:
		return
	if dragging_direction >= 0:
		var moved = dragging_block.position - dragging_block_position
		var moved_length = moved.length()
		if force_back:
			dragging_block.position = dragging_block_position
		elif moved_length < Triangle.SideLength / 2.0:
			dragging_block.move_to(dragging_block_position)
			yield(dragging_block, "moved")
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
	self.current_direction = -1


func complete_move(block, di: int):
	block.moved_pos += Triangle.ID_DIRECTIONS[di]
	var to_move = Triangle.DIRECTIONS[di] * Triangle.SideLength
	block.move_to(dragging_block_position + to_move)
	yield(block, "moved")
	dragging_block_position = dragging_block_position + to_move
	dragging_start += to_move
	var step = {
		"type": "move",
		"block": block,
		"direction": di
	}
	steps.append([step])
	print(step)
	emit_signal("step_completed", step)
	update_directions()


var wrong_move_sfx_played = -1
func process_dragging():
	if dragging_block == null or is_busy() or \
			last_processed < steps.size():  # to avoid moving too fast
		return
	var block = dragging_block
	if not Input.is_mouse_button_pressed(BUTTON_LEFT):
		SFX.stop_keeping(SFX.PLAYER_MOVE)
		cancel_drag()
		return
	if block.is_player():
		SFX.keep_playing(SFX.PLAYER_MOVE)
	var mp = block.get_global_mouse_position() - dragging_start
	var mp_r2 = mp.length_squared()
	if dragging_direction == -1 and mp_r2 >= DRAGGING_THRESHOLD:
		var di = Triangle.get_direction_in_availables(mp, available_directions)
		if di == null:
			if wrong_move_sfx_played <= 3:
				wrong_move_sfx_played += 1
			if wrong_move_sfx_played == 3:
				SFX.keep_playing(SFX.WRONG_MOVE)
		else:
			wrong_move_sfx_played = -1
			dragging_direction = di
	if dragging_direction >= 0:
		var direction = Triangle.DIRECTIONS[dragging_direction]
		var opposite = Triangle.get_opposite(dragging_direction)
		var to_move = mp.dot(direction)
		if to_move <= 0:
			if opposite in available_directions:
				if to_move <= -Triangle.SideLength:
					complete_move(block, opposite)
					to_move = 0.0
				else:
					self.current_direction = opposite
			else:
				to_move = 0.0
		elif dragging_direction in available_directions:
			if to_move >= Triangle.SideLength:
				complete_move(block, dragging_direction)
				to_move = 0.0
			else:
				self.current_direction = dragging_direction
		else:
			to_move = 0.0
		if to_move == 0.0:
			self.current_direction = -1
		else:
			block.position = dragging_block_position + to_move * direction


func is_busy():
	return not initialized or animating.size() > 0 or is_processing


func get_player():
	for block in blocks:
		if block.is_player():
			return block
	return null

func _next_unhandled_event():
	for block in blocks:
		for terrain in terrains:
			if terrain.check_interact(block):
				return [terrain, block]
	var player = get_player()
	for block in blocks:
		if block != player:
			if block.check_interact(player):
				return [block, player]
	return null


var is_processing = false
func process_events():
	if is_busy() or last_processed == steps.size():
		return
	is_processing = true
	var e = _next_unhandled_event()
	print(last_processed, "\t", e)
	if e == null:
		last_processed = steps.size()
	else:
		cancel_drag(true)
		var terrain = e[0]  # or_block
		var block = e[1]
		terrain.interact(block)
		var step = yield(terrain, "interacted")
		if step == null:
			return
		print(step)
		if steps.size() > 0 and step.size() > 0:
			var last_step = steps.back()
			last_step.append(step)
		emit_signal("step_completed", step)
	is_processing = false


func _process(_delta):
	if is_busy():
		return
	process_dragging()
	process_events()


var initial_cache = {}

func initialize():
	if initialized:
		return
	for terrain in terrains:
		print(terrain.name, "\t", terrain.pos_ids)
	for block in blocks:
		print(block.name, "\t", block.pos_ids)
	# TODO: Intialize initial_cache
	print("Initialized!")
	initialized = true


func restart():
	if is_busy():
		yield(self, "step_completed")
	print("Restarting...")
	initialized = false
	steps = []
	blocks_map = {}
	for block in blocks:
		block.restore_original()
		for pos_id in block.pos_ids:
			blocks_map[pos_id] = block
	for terrain in terrains:
		terrain.restore()
	initialize()


func go_back():
	if is_busy():
		return
	if steps.size() == 0:
		SFX.play(SFX.GENERAL_UI_02)
		# No step to go back
		return
	SFX.play(SFX.UNDO)
	var last_step = steps.pop_back()
	is_processing = true
	while last_step.size() > 0:
		var step = last_step.pop_back()
		print("Undo: ", step)
		match step["type"]:
			"move":
				var block = step["block"]
				var direction = step["direction"]
				block.move_with_logics(
					Triangle.get_opposite(direction), 5
				)
				yield(block, "moved")
			"group":
				var player = step["player"]
				if step["grouped"]:
					player.ungroup_all(false)
				else:
					player.group_blocks(false)
			_:
				if "terrain" in step:
					var terrain = step["terrain"]
					terrain.go_back(step)
					if yield(terrain, "interacted"):
						return
				elif "undo" in step:
					var undo = step["undo"] as FuncRef
					var t = undo.call_func(step)
					if yield(t, "interacted"):
						return
				else:
					print("Cannot go back for ", step)
	last_processed -= 1
	is_processing = false
