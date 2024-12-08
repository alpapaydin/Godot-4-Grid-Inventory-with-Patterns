extends Control

var texture: TextureRect:
	get():
		return $TextureRect

var item_pattern: Array
var pattern_tiles: Array = []
var tile_size: Vector2
var single_slot_mode := false:
	set(val):
		if val != single_slot_mode:
			if val:
				update_pattern_display(Apeloot.item_patterns["1x1"])
				texture.custom_minimum_size = Apeloot.INVENTORY_ITEM_SIZE
				texture.pivot_offset = Apeloot.INVENTORY_ITEM_SIZE / 2
			else:
				update_pattern_display(item_pattern)
				texture.custom_minimum_size = custom_minimum_size
				texture.pivot_offset = custom_minimum_size / 2
		single_slot_mode = val

func _ready():
	tile_size = Apeloot.INVENTORY_ITEM_SIZE
	create_pattern_tiles(item_pattern)

func create_pattern_tiles(pattern):
	for y in range(len(pattern)):
		for x in range(len(pattern[y])):
			if pattern[y][x] == 1:
				var tile = ColorRect.new()
				tile.size = tile_size
				tile.position = Vector2(x * tile_size.x, y * tile_size.y)
				texture.add_child(tile)
				pattern_tiles.append(tile)

func update_pattern_display(pattern):
	for tile in pattern_tiles:
		tile.queue_free()
	pattern_tiles.clear()
	create_pattern_tiles(pattern)

func set_collision_state(can_place: bool):
	var color = Color.GREEN if can_place else Color.RED
	color.a = 0.5  # Set alpha for transparency
	for tile in pattern_tiles:
		tile.color = color
