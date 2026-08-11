extends GridContainer


# This script manages the inventory grid, including placing and removing items, checking if items can be placed, and updating the preview of where an item would be placed.
@export var COLS := 10
@export var ROWS := 7
@export var CELL_SIZE := 64
@export var CELL_GAP := 4
var CELL_STEP := CELL_SIZE + CELL_GAP

const COLOR_NORMAL := Color(0.22, 0.22, 0.22)
const COLOR_VALID := Color(0.2, 0.75, 0.3, 0.6)
const COLOR_INVALID := Color(0.851, 0.2, 0.2, 0.6)

var grid: Array = []
var cells: Array = []

@onready var item_layer: Control = $ItemLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	CELL_STEP = CELL_SIZE + CELL_GAP
	columns = COLS
	add_theme_constant_override("h_separation", CELL_GAP)
	add_theme_constant_override("v_separation", CELL_GAP)
	for y in range(ROWS):
		grid.append([])
		for x in range(COLS):
			grid[y].append(null)
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.color = Color.WHITE
			cell.self_modulate = COLOR_NORMAL
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cell)
			cells.append(cell)
	item_layer.top_level = true
	item_layer.global_position = global_position
	for item in item_layer.get_children():
		auto_place(item)

# Places the item in the first free cell it fits in, scanning row by row. Returns true if a spot was found.
func auto_place(item) -> bool:
	for row in range(ROWS):
		for col in range(COLS):
			if can_place(item, row, col):
				place_item(item, row, col)
				return true
	return false

# Check to see if item can be placed at the given row and column. Returns true if it can, false otherwise.
func can_place(item, row: int, col: int) -> bool:
	if row < 0 or col < 0:
		return false
	if row + item.cur_h() > ROWS or col + item.cur_w() > COLS:
		return false
	for y in range(item.cur_h()):
		for x in range(item.cur_w()):
			if grid[row + y][col + x] != null:
				return false
	return true

# Place the item at the given row and column, updating the grid and the item's position. Assumes that can_place has already been called and returned true.
func place_item(item, row: int, col: int) -> void:
	for y in range(item.cur_h()):
		for x in range(item.cur_w()):
			grid[row + y][col + x] = item
	item.grid_row = row
	item.grid_col = col
	item.global_position = cell_to_world(row, col)
	clear_preview()

# Remove the item from the grid, updating the grid and the item's position. Assumes that the item is currently in the grid.
func remove_item(item) -> void:
	if item.grid_row < 0:
		return
	for y in range(item.cur_h()):
		for x in range(item.cur_w()):
			grid[item.grid_row + y][item.grid_col + x] = null
	item.grid_row = -1
	item.grid_col = -1
	clear_preview()

# Try to place the item at the given world position. Returns true if the item was placed, false otherwise.
func try_place(item, world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos, item.cur_w(), item.cur_h())
	if cell.x == -1:
		return false
	if not can_place(item, cell.y, cell.x):
		return false
	place_item(item, cell.y, cell.x)
	return true

# Update the preview of where the item would be placed if dropped at the given world position. Colors the cells green if the item can be placed, red if it cannot, and clears the preview if the position is invalid.
func update_preview(item, world_pos: Vector2) -> void:
	clear_preview()
	var cell := world_to_cell(world_pos, item.cur_w(), item.cur_h())
	if cell.x == -1:
		return
	var color := COLOR_VALID if can_place(item, cell.y, cell.x) else COLOR_INVALID
	for y in range(item.cur_h()):
		for x in range(item.cur_w()):
			color_cell(cell.y + y, cell.x + x, color)

# Clear the preview of where the item would be placed. Resets all cells to their normal color.
func clear_preview() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			color_cell(y, x, COLOR_NORMAL)

# Convert a world position to a cell position in the grid. Returns a Vector2i with the column and row of the cell, or (-1, -1) if the position is outside the grid.
func world_to_cell(world_pos: Vector2, w: int, h: int) -> Vector2i:
	var local := world_pos - global_position
	local -= Vector2(w, h) * CELL_STEP * 0.5
	var col := roundi(local.x / CELL_STEP)
	var row := roundi(local.y / CELL_STEP)
	if row < 0 or col < 0 or row + h > ROWS or col + w > COLS:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

# Convert a cell position in the grid to a world position. Returns the world position of the top-left corner of the cell.
func cell_to_world(row: int, col: int) -> Vector2:
	return global_position + Vector2(col, row) * CELL_STEP

# Color a cell in the grid with the given color. The cell is specified by its row and column.
func color_cell(row: int, col: int, color: Color) -> void:
	cells[row * COLS + col].self_modulate = color
