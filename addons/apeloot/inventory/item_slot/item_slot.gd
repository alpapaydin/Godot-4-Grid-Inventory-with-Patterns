extends PanelContainer

signal slotClicked(slotId)

var anim_player : AnimationPlayer:
	get():
		return $AnimationPlayer
		
var parent_inventory : GridInventory:
	set(val):
		parent_inventory = val
		if val.slot_background:
			$Background.texture = val.slot_background
		if val.slot_icon:
			$Icon.texture = val.slot_icon
			
var occupying_item: DraggableItem = null:
	set(val):
		if val:
			if val != occupying_item:
				val.itemUpgraded.connect(refresh_props)
			$Icon.visible = false
			$Background.modulate = val.get_rarity_data()["color"]
			mouse_default_cursor_shape = CURSOR_POINTING_HAND
		else	:
			if is_instance_valid(occupying_item):
				occupying_item.itemUpgraded.disconnect(refresh_props)
			can_drag = true
			$Icon.visible = true
			$Background.modulate = Color("b2b2b2")
			mouse_default_cursor_shape = CURSOR_ARROW
		occupying_item = val
		
var can_drag := true:
	set(val):
		can_drag = val
		$Blocked.visible = not val
var slot_id := -1
var full := false
var showing_tooltip: HBoxContainer

func _process(delta):
	if showing_tooltip:
		adjust_tooltip_pos()

func _get_drag_data(_at_position):
	if occupying_item and can_drag:
		occupying_item.texture.drag_item()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slotClicked.emit(slot_id)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not "item" in data:
		return false
	var item = data["item"]
	var center_slot = parent_inventory.find_slot_at_position(at_position)
	return parent_inventory.can_place_item(item, center_slot)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item = data["item"]
	var center_slot = parent_inventory.find_slot_at_position(at_position)
	parent_inventory.handle_item_drop(item, center_slot)

func refresh_props() -> void:
	occupying_item = occupying_item

func _on_mouse_entered():
	show_tooltip()

func _on_mouse_exited():
	hide_tooltip()

func show_tooltip():
	if is_instance_valid(occupying_item):
		var tooltip_cont := HBoxContainer.new()
		var tooltip = spawn_tooltip(occupying_item)
		tooltip_cont.add_child(tooltip)
		tooltip_cont.z_index = 10
		Apeloot.temp_node.add_child(tooltip_cont)
		showing_tooltip = tooltip_cont

func spawn_tooltip(for_item) -> ItemTooltip:
	var tooltip_scene := preload("res://addons/apeloot/inventory/item_tooltip/item_tooltip.tscn")
	var tooltip := tooltip_scene.instantiate()
	tooltip.item_ref = for_item
	return tooltip

func hide_tooltip():
	if is_instance_valid(showing_tooltip):
		showing_tooltip.queue_free()
		showing_tooltip = null

func adjust_tooltip_pos():
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = showing_tooltip.get_rect().size
	var mouse_position = get_global_mouse_position()
	var new_position = mouse_position + Vector2(15, 15)
	# Check if the tooltip overflows on the right
	if new_position.x + tooltip_size.x > screen_size.x:
		new_position.x = mouse_position.x - tooltip_size.x - 15  # Move to the left
	# Check if the tooltip overflows at the bottom
	if new_position.y + tooltip_size.y > screen_size.y:
		new_position.y = mouse_position.y - tooltip_size.y - 15  # Move up
	showing_tooltip.position = new_position
