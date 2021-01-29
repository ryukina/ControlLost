tool
extends KinematicBody2D
class_name Block

export var is_draggable = true setget set_is_draggable
export var border_color = Color.black setget set_border_color
export var border_color_hovered = Color.black
export var border_color_dragging = Color.white
export var border_width = 6 setget set_border_width

var hovered = false setget set_hovered
var is_dragging = false setget set_is_dragging
const GameManager = preload("res://core/game_manager.gd")
var game: GameManager
var pos_ids = []
var moved_pos = Vector2.ZERO
var original_position: Vector2


func _ready():
	original_position = position


# Also update the position
func set_is_draggable(value):
	is_draggable = value
	position = Triangle.get_nearest_point(position)


func set_border_color(value):
	border_color = value
	if has_node("Boundary"):
		$Boundary.update()


func set_border_width(value):
	border_width = value
	if has_node("Boundary"):
		$Boundary.update()


func set_hovered(value):
	if hovered == value:
		return
	hovered = value
	$Boundary.update()


func set_is_dragging(value):
	if is_dragging == value:
		return
	is_dragging = value
	$Boundary.update()


func _process(_delta):
	if hovered && has_node("Boundary"):
		$Boundary.update()


func get_current_border_color():
	return border_color_dragging if is_dragging else \
		border_color_hovered if hovered and game.dragging_block == null else \
		border_color


func _on_Boundary_draw():
	var bc = get_current_border_color()
	var vertices = $TrianglePolygonShape.polygon
	var boundary = $Boundary
	var n = vertices.size()
	for i in range(n - 1):
		boundary.draw_line(vertices[i], vertices[i + 1], bc, border_width)
	boundary.draw_line(vertices[n - 1], vertices[0], bc, border_width)
	for i in range(n):
		boundary.draw_circle(vertices[i], border_width / 2, bc)
	boundary.z_index = 1 if is_dragging or \
		hovered and game.dragging_block == null else 0


func _on_input_event(_viewport, event, _shape_idx):
	if not is_draggable:
		return
	if event is InputEventMouseButton && game != null:
		if event.button_index != BUTTON_LEFT:
			return
		if event.pressed:
			game.drag(self)
		else:
			game.cancel_drag(self)
	elif event is InputEventMouseMotion:
		pass


func _on_mouse_entered():
	self.hovered = true


func _on_mouse_exited():
	self.hovered = false
