extends Control

# This script manages the inventory items, including their size, texture, rotation, and dragging behavior. It also handles the interaction with the inventory grid for placing and removing items.
@export var item_w := 1
@export var item_h := 1
@export var item_texture: Texture2D

@onready var visual: TextureRect = get_child(0)

var grid_row := -1
var grid_col := -1
var rotated := false
var dragging := false
var grid = null

var old_row := -1
var old_col := -1
var old_rotated := false

func _ready() -> void:
	grid = $"../.."
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	visual.texture = item_texture
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	update_item()	

# Returns the current width of the item, taking into account its rotation.
func cur_w() -> int:
	return item_h if rotated else item_w

# Returns the current height of the item, taking into account its rotation.
func cur_h() -> int:
	return item_w if rotated else item_h

# Updates the item's visual representation based on its current size and rotation. Adjusts the size, pivot offset, and rotation of the visual element accordingly.
func update_item() -> void:
	size = Vector2(cur_w(), cur_h()) * grid.CELL_STEP - Vector2.ONE * grid.CELL_GAP
	pivot_offset = size * 0.5
	var draw_size := size if not rotated else Vector2(size.y, size.x)
	visual.size = draw_size
	visual.position = (size - draw_size) * 0.5
	visual.pivot_offset = draw_size * 0.5
	visual.rotation_degrees = 90.0 if rotated else 0.0

# Gui input event handler for the item. Starts dragging on left mouse button press, and rotates the item on right mouse button release if it was being dragged.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_drag()
		elif dragging and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			rotate_item()

# Handles input events for dragging and rotating the item. Updates the item's position based on mouse movement, rotates the item on 'R' key press, and ends dragging on left mouse button release.
func _input(event: InputEvent) -> void:
	if not dragging:
		return
	var mouse := get_global_mouse_position()
	if event is InputEventMouseMotion:
		global_position = mouse - size * 0.5
		grid.update_preview(self, mouse)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		rotate_item()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		end_drag()

# Places the item in the grid at the specified row and column. Updates the grid and the item's position accordingly.
func start_drag() -> void:
	old_row = grid_row
	old_col = grid_col
	old_rotated = rotated
	dragging = true
	z_index = 10
	grid.remove_item(self)

# Ends the dragging of the item. Attempts to place the item in the grid at the current mouse position. If placement fails, restores the item's previous rotation and position in the grid.
func end_drag() -> void:
	dragging = false
	z_index = 0
	if not grid.try_place(self, get_global_mouse_position()):
		rotated = old_rotated
		update_item()
		if old_row >= 0 and old_col >= 0:
			grid.place_item(self, old_row, old_col)
	grid.clear_preview()

# Rotates the item by toggling its rotation state. Updates the item's visual representation and adjusts its global position to keep it centered after rotation. Also updates the grid preview based on the new rotation state.
func rotate_item() -> void:
	var center := global_position + size * 0.5
	rotated = !rotated
	update_item()
	global_position = center - size * 0.5
	grid.update_preview(self, get_global_mouse_position())
