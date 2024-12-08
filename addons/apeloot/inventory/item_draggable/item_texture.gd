extends TextureRect
class_name DraggableTexture

signal dragStarted()

var drag_preview: Control = null
var full_size: Vector2
var original_position: Vector2
var is_dragging = false:
	set(val):
		is_dragging = val
		visible = not val
		$"../StackLabel".visible = not val

@onready var item_node : DraggableItem = get_parent()

func _get_drag_data(_at_position: Vector2) -> Variant:
	return drag_item()
	
func create_drag_preview():
	var preview_scene := preload("res://addons/apeloot/inventory/item_draggable/drag_preview.tscn")
	drag_preview = preview_scene.instantiate()
	var ntexture = drag_preview.texture
	ntexture.texture = texture
	ntexture.custom_minimum_size = full_size
	ntexture.pivot_offset = full_size / 2
	ntexture.rotation = rotation
	ntexture.z_index = 1
	drag_preview.custom_minimum_size = full_size
	drag_preview.item_pattern = Apeloot.item_patterns[Apeloot.items[item_node.id]["pattern"]] if "pattern" in Apeloot.items[item_node.id] else Apeloot.item_patterns["1x1"]
	Apeloot.temp_node.add_child(drag_preview)
	update_drag_preview_position()

func update_drag_preview_position():
	if not (drag_preview and is_instance_valid(drag_preview)):
		return
	var mouse_position = get_global_mouse_position()
	var inventory = find_inventory_at_position(mouse_position)
	if not inventory or inventory.pickup_only:
		reset_drag_preview(mouse_position)
		return
	var center_slot = inventory.find_slot_at_position(mouse_position)
	if center_slot == -1:
		reset_drag_preview(mouse_position)
		return
	drag_preview.single_slot_mode = inventory.single_slot
	var snap_position = inventory.calculate_item_position(item_node, center_slot)
	drag_preview.position = snap_position
	var can_place = inventory.can_place_item(item_node, center_slot)
	drag_preview.set_collision_state(can_place)

func reset_drag_preview(mouse_position):
	drag_preview.single_slot_mode = false
	drag_preview.global_position = mouse_position - drag_preview.size / 2
	drag_preview.set_collision_state(false)

func _process(_delta):
	if is_dragging:
		update_drag_preview_position()

func _input(event: InputEvent) -> void:
	if is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drop_item()
		elif event.is_action_pressed("RightClick"):
			rotate_item()

func drag_item() -> Variant:
	is_dragging = true
	item_node.original_orientation = item_node.orientation
	original_position = item_node.position
	create_drag_preview()
	var data = {"item": item_node, "original_inventory": item_node.parent_inventory}
	if item_node.parent_inventory:
		item_node.parent_inventory.deregister_item(item_node)
	set_process(true)
	dragStarted.emit()
	return data

func drop_item():
	is_dragging = false
	# Force drop if it wasn't triggered automatically
	var drop_position = get_global_mouse_position()
	var inventory = find_inventory_at_position(drop_position)
	if inventory and not inventory.pickup_only:
		var slot_id = inventory.find_slot_at_position(drop_position)
		var slot = inventory.get_slot_by_index(slot_id)
		if slot:
			slot._drop_data(drop_position, {"item": item_node})
	else:
		var parent_inventory = item_node.parent_inventory
		var center_slot = parent_inventory.find_slot_at_position(drop_position)
		parent_inventory.handle_item_drop(item_node, center_slot)

func rotate_item():
	item_node.orientation = (item_node.orientation + 1) % 4

func update_rotation():
	rotation = item_node.orientation * PI / 2
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.texture.rotation = rotation
	update_drag_preview_position()

func end_drag():
	is_dragging = false
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	set_process(false)

func find_inventory_at_position(pos: Vector2) -> GridInventory:
	for inv in Apeloot.inventory_refs.values():
		if inv.get_global_rect().has_point(pos):
			return inv
	return null
