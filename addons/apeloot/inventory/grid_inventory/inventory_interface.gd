extends PanelContainer
class_name GridInventory

@export var id := ""
@export var slot_count := 30:
	set(val):
		slot_count = val
		_reset()
@export var columns := 10
@export var single_slot := false
@export var full_size := false
@export var pickup_only := false
@export var type_only := false
@export var slot_background : CompressedTexture2D
@export var slot_icon : CompressedTexture2D
@export var slot_separation := Vector2(0,0)

signal item_placed(item: DraggableItem)
signal item_updated(item: DraggableItem)
signal item_removed(item: DraggableItem)
signal item_moved(item: DraggableItem, to_inventory: GridInventory)
signal item_reparented(item: DraggableItem, new_parent: GridInventory)

var grid: GridContainer
var items_node: Control
var items = []  # keeps item references
var item_states = []  # keeps items data, you can save this to save inventory, then load it with load_inventory()

func _ready():
	initialize_inventory()

func load_inventory(data: Dictionary):
	initialize_inventory(data.inventories[id])

func initialize_inventory(states: Array = item_states):
	_reset()
	reconstruct_grid_from_states(states)

func _enter_tree():
	Apeloot.inventory_refs[id] = self

func _exit_tree():
	Apeloot.inventory_refs.erase(id)

func _reset():
	for c in get_children():
		c.queue_free()
	construct_children()
	drawSlots()

func construct_children():
	var scroll_scene := preload("res://addons/apeloot/inventory/grid_inventory/scroll_container.tscn")
	var scroll_node := scroll_scene.instantiate()
	add_child(scroll_node)
	grid = scroll_node.get_node("PanelContainer/InventoryGrid")
	grid.add_theme_constant_override("h_separation", slot_separation.x)
	grid.add_theme_constant_override("v_separation", slot_separation.y)
	items_node = scroll_node.get_node("PanelContainer/Items")
	var row_count = slot_count / columns
	grid.columns = columns
	if full_size:
		custom_minimum_size = Vector2(0, (Apeloot.INVENTORY_ITEM_SIZE.y + grid.get_theme_constant("v_separation") + 1) * row_count)

func drawSlots():
	var slotScene := preload("res://addons/apeloot/inventory/item_slot/item_slot.tscn")
	for i in range(slot_count):
		var slot := slotScene.instantiate()
		slot.parent_inventory = self
		slot.slot_id = i
		slot.slotClicked.connect(slot_click) # for debug
		grid.add_child(slot)

func calculate_item_position(item, center_slot, global=true):
	var pattern = get_rotated_pattern(item)
	var pattern_width = len(pattern[0]) if not single_slot else 1
	var pattern_height = len(pattern) if not single_slot else 1
	var slot_size = grid.get_child(0).size
	var center_slot_global_position = grid.get_child(center_slot).global_position if global else grid.get_child(center_slot).position
	var offset_x = pattern_width / 2.0 if pattern_width % 2 == 0 else (pattern_width - 1) / 2.0
	var offset_y = pattern_height / 2.0 if pattern_height % 2 == 0 else (pattern_height - 1) / 2.0
	var global_item_position = center_slot_global_position - Vector2(offset_x, offset_y) * slot_size
	return global_item_position if global else grid.position + global_item_position

#For save/load, only need to save item_states array and load it, then call below function
func reconstruct_grid_from_states(saved_states):
	for item in items:
		remove_item(item)
	items.clear()
	item_states.clear()
	for slot in grid.get_children():
		slot.full = false
	for state in saved_states:
		var item = spawn_item(state.id, state.stack_count)
		for prop in item.saved_props:
			item.set(prop, state.get(prop))
		mark_slots_as_full(item, state.previous_center_slot)
		items.append(item)
		item_states.append(state)

func spawn_item(item_id, stack_count = 1):
	var item_scene = preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item = item_scene.instantiate()
	item.id = item_id
	item.parent_inventory = self
	items_node.add_child(item)
	return item

func can_place_item(item, center_slot_id):
	if pickup_only:
		return false
	if center_slot_id == -1:
		return false
	if type_only:
		pass
		#implement your type checking logic
	if single_slot:
		return false if get_slot_by_index(center_slot_id).full else true
	var pattern = get_rotated_pattern(item)
	var pattern_width = len(pattern[0])
	var pattern_height = len(pattern)
	var grid_width = grid.columns
	var grid_height = slot_count / grid_width
	var start_slot_x = center_slot_id % grid_width - int(pattern_width / 2.0)
	var start_slot_y = center_slot_id / grid_width - int(pattern_height / 2.0)
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:
				var slot_x = start_slot_x + x
				var slot_y = start_slot_y + y
				var slot_id = slot_y * grid_width + slot_x
				if slot_x < 0 or slot_y < 0 or slot_x >= grid_width or slot_y >= grid_height:
					return false
				var slot = grid.get_child(slot_id)
				if slot.full:
					return false
					# Check if this is not the item's own previous position
					#if item.parent_inventory == self and item.previous_center_slot == -1 or slot_id != item.previous_center_slot:
					#	return false
	return true

func snap_item_to_grid(item, center_slot):
	item.position = calculate_item_position(item, center_slot, false)
	item.previous_center_slot = center_slot
	if not items.has(item):
		items.append(item)
	mark_slots_as_full(item, center_slot)
	update_item_state(item)

func update_item_state(item: DraggableItem):
	var item_state = {}
	for prop in item.saved_props:
		item_state[prop] = item.get(prop)
	var existing_index = -1
	for i in range(item_states.size()):
		if item_states[i].instance_id == item.instance_id:
			existing_index = i
			break
	if existing_index != -1:
		item_states[existing_index] = item_state
	else:
		item_states.append(item_state)
	item_updated.emit(item)
	Apeloot.item_updated.emit(self, item)

func get_occupied_slots(item, center_slot_id):
	if single_slot:
		return [center_slot_id]
	var occupied_slots = []
	var pattern_data = get_rotated_pattern(item)
	var pattern_width = len(pattern_data[0])
	var pattern_height = len(pattern_data)
	var grid_width = grid.columns
	var start_slot_x = center_slot_id % grid_width - int(pattern_width / 2.0)
	var start_slot_y = center_slot_id / grid_width - int(pattern_height / 2.0)
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern_data[y][x] == 1:
				var slot_x = start_slot_x + x
				var slot_y = start_slot_y + y
				var slot_id = slot_y * grid_width + slot_x
				if slot_x >= 0 and slot_y >= 0 and slot_x < grid_width and slot_id < grid.get_child_count():
					occupied_slots.append(slot_id)
	return occupied_slots

func get_rotated_pattern(item):
	var original_pattern = Apeloot.item_patterns[Apeloot.items[item.id]["pattern"]] if "pattern" in Apeloot.items[item.id] else Apeloot.item_patterns["1x1"]
	var rotated_pattern = []
	match item.orientation:
		0:  # No rotation
			return original_pattern
		1:  # 90 degrees clockwise
			for x in range(len(original_pattern[0])):
				var new_row = []
				for y in range(len(original_pattern) - 1, -1, -1):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
		2:  # 180 degrees
			for y in range(len(original_pattern) - 1, -1, -1):
				var new_row = []
				for x in range(len(original_pattern[0]) - 1, -1, -1):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
		3:  # 270 degrees clockwise (90 degrees counterclockwise)
			for x in range(len(original_pattern[0]) - 1, -1, -1):
				var new_row = []
				for y in range(len(original_pattern)):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
	return rotated_pattern

func mark_slots_as_full(item, center_slot_id: int):
	var occupied_slots = get_occupied_slots(item, center_slot_id)
	for slot_id in occupied_slots:
		var slot = grid.get_child(slot_id)
		slot.occupying_item = item
		slot.full = true

func clear_slots(item, center_slot_id: int):
	var occupied_slots = get_occupied_slots(item, center_slot_id)
	for slot_id in occupied_slots:
		var slot = grid.get_child(slot_id)
		slot.occupying_item = null
		slot.full = false

func remove_item_state(item):
	var index_to_remove = -1
	for i in range(item_states.size()):
		if item_states[i].instance_id == item.instance_id:
			index_to_remove = i
			break
	if index_to_remove != -1:
		item_states.remove_at(index_to_remove)

func deregister_item(item):
	item_removed.emit(item)
	Apeloot.item_removed.emit(self, item)
	clear_slots(item, item.previous_center_slot)
	remove_item_state(item)
	items.erase(item)

func remove_item(item):
	deregister_item(item)
	if is_instance_valid(item):
		item.queue_free()

func handle_item_drop(dragged_item: DraggableItem, target_slot):
	var target_item = get_item_at_slot(target_slot)
	var drop_successful = true
	# Case 1: Pickup only mode
	if pickup_only:
		_reset_dragged_item(dragged_item)
		_end_drag(dragged_item)
		return drop_successful
	# Case 2: Dropping on itself
	if target_item and target_item.instance_id == dragged_item.instance_id:
		_reset_dragged_item(dragged_item)
		_end_drag(dragged_item)
		return drop_successful
	# Case 3: Stacking items
	if target_item and target_item.id == dragged_item.id and target_item.can_stack:
		_process_stack(dragged_item, target_item)
		_end_drag(dragged_item)
		return drop_successful
	# Case 4: Merging items
	if target_item and target_item.can_merge_with(dragged_item):
		_merge_items(dragged_item, target_item)
		_end_drag(dragged_item)
		return drop_successful
	# Case 5: Normal placement
	if can_place_item(dragged_item, target_slot):
		_place_item(dragged_item, target_slot)
	else:
		_reset_dragged_item(dragged_item)
	dragged_item.parent_inventory.item_placed.emit(dragged_item)
	Apeloot.item_added.emit(dragged_item.parent_inventory, dragged_item)
	_end_drag(dragged_item)
	return drop_successful

func _reset_dragged_item(dragged_item: DraggableItem):
	dragged_item.orientation = dragged_item.original_orientation
	dragged_item.parent_inventory.snap_item_to_grid(dragged_item, dragged_item.previous_center_slot)

func _process_stack(dragged_item: DraggableItem, target_item):
	var remainder = target_item.add_to_stack(dragged_item.stack_count)
	if remainder == 0:
		_remove_dragged_item(dragged_item)
	else:
		dragged_item.stack_count = remainder
		_reset_dragged_item(dragged_item)
	update_item_state(target_item)

func _merge_items(dragged_item: DraggableItem, target_item):
	_remove_dragged_item(dragged_item)
	target_item.increase_rarity()
	update_item_state(target_item)

func _place_item(dragged_item: DraggableItem, target_slot):
	if dragged_item.parent_inventory != self:
		if dragged_item.parent_inventory:
			dragged_item.parent_inventory.item_moved.emit(dragged_item, self)
		dragged_item.parent_inventory.item_reparented.emit(dragged_item, self)
		dragged_item.reparent(items_node)
		dragged_item.parent_inventory = self
	dragged_item.parent_inventory.snap_item_to_grid(dragged_item, target_slot)

func _remove_dragged_item(dragged_item: DraggableItem):
	if dragged_item.parent_inventory != self:
		dragged_item.parent_inventory.item_moved.emit(dragged_item, self)
	dragged_item.parent_inventory.remove_item(dragged_item)

func _end_drag(dragged_item: DraggableItem):
	if is_instance_valid(dragged_item) and dragged_item.get_node("ItemTexture"):
		dragged_item.get_node("ItemTexture").end_drag()

func get_item_at_slot(slot_id):
	for item in items:
		if item.previous_center_slot == slot_id:
			return item
	return null

func find_slot_at_position(pos: Vector2) -> int:
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i)
		if slot.get_global_rect().has_point(pos):
			return i
	return -1

func get_slot_by_index(idx):
	var slot = grid.get_child(idx)
	return slot if slot else null

func is_slot_occupied(idx):
	return get_slot_by_index(idx).full

func get_item_at_position(pos: Vector2) -> Node:
	for item in items:
		if item.get_node("ItemTexture").get_global_rect().has_point(pos):
			return item
	return null

func find_valid_slot(item) -> int:
	for i in range(grid.get_child_count()):
		if can_place_item(item, i):
			return i
	return -1

func try_fit_and_place(item: DraggableItem) -> bool:
	var fit_slot = fit_given_item(item)
	if fit_slot != -1:
		_place_item(item, fit_slot)
		return true
	return false

func fit_given_item(item: DraggableItem) -> int:
	for slot_id in range(grid.get_child_count()):
		if can_place_item(item, slot_id):
			return slot_id
	return -1

#debug funcs
func slot_click(slot_id):
	if is_slot_occupied(slot_id):
		return
	var item = spawn_random_item()
	var can_place = can_place_item(item, slot_id)
	if can_place:
		snap_item_to_grid(item, slot_id)
	else:
		item.queue_free()

func spawn_random_item():
	var itemSc := preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item := itemSc.instantiate()
	item.id = Apeloot.items.keys().pick_random()
	item.parent_inventory = self
	items_node.add_child(item)
	return item
