extends Control
class_name DraggableItem

signal dragStarted(item)
signal itemUpgraded

@export var id := "":
	set(val):
		if val in Apeloot.items:
			id = val
			texture.texture = load(Apeloot.ITEM_ICONS_PATH + val + ".png")
			var pattern = Apeloot.item_patterns[Apeloot.items[val]["pattern"]] if "pattern" in Apeloot.items[val] else Apeloot.item_patterns["1x1"]
			texture.full_size = Apeloot.INVENTORY_ITEM_SIZE * len(pattern)
			if "stack" in Apeloot.items[val] and Apeloot.items[val]["stack"] > 1:
				can_stack = true
			if "merge" in Apeloot.items[val] and Apeloot.items[val]["merge"]:
				can_merge = true
			if "stats" in Apeloot.items[val] and not stats:
				stats = Apeloot.items[val].stats.duplicate()
			if "price" in Apeloot.items[val] and not price:
				price = Apeloot.items[val].price
var instance_id: String
var parent_inventory: GridInventory:
	set(val):
		if parent_inventory != val:
			parent_inventory = val
			if val:
				$ItemTexture.custom_minimum_size = $ItemTexture.full_size if not val.single_slot else Apeloot.INVENTORY_ITEM_SIZE
				$ItemTexture.pivot_offset = $ItemTexture.custom_minimum_size/2
				adjust_stack_label_pos()
var texture: 
	get():
		return $ItemTexture
var previous_center_slot := -1
var original_orientation := 0
var orientation := 0:
	set(val):
		orientation = val
		adjust_stack_label_pos()
		texture.update_rotation()

#For save/load
var saved_props := ["id", "instance_id", "position", "orientation", "previous_center_slot", "stack_count", "rarity", "stats", "price"]

var can_merge := false
var can_stack := false
var stack_count := 1:
	set(val):
		stack_count = val
		set_stack_label(val)
var price : int
var rarity := Apeloot.Rarity.COMMON
var stats : Dictionary
var check_can_afford := false

@onready var drop_particles := $GPUParticles2D2
func _ready():
	texture.dragStarted.connect(start_drag)
	set_stack_label(stack_count)
	instance_id = generate_unique_id()

func start_drag():
	dragStarted.emit(self)

func set_stack_label(val):
	if val > 1:
		$StackLabel.text = str(val)
	else:
		$StackLabel.text = ""

func generate_unique_id() -> String:
	return str(get_instance_id())

func get_max_stack() -> int:
	return Apeloot.items[id].get("stack", 1)

func add_to_stack(amount: int) -> int:
	var max_stack = get_max_stack()
	var space_left = max_stack - stack_count
	var added = min(amount, space_left)
	stack_count += added
	return amount - added

func adjust_stack_label_pos():
	if parent_inventory.single_slot:
		$StackLabel.position = Vector2(0,0)
	else:
		var rotated_pattern = parent_inventory.get_rotated_pattern(self)
		var matching_pos = get_first_left_uppermost(rotated_pattern)
		$StackLabel.position = Vector2(Apeloot.INVENTORY_ITEM_SIZE.x * matching_pos.x, Apeloot.INVENTORY_ITEM_SIZE.y * matching_pos.y)

func get_first_left_uppermost(pattern: Array) -> Vector2:
	for x in range(pattern[0].size()):
		for y in range(pattern.size()):
			if pattern[y][x] == 1:
				return Vector2(x, y)
	return Vector2(-1, -1)

func get_item_data():
	return {
		"id" = id,
		"stack" = stack_count,
	}

func get_rarity_data() -> Dictionary:
	return Apeloot.rarities[rarity]

func can_merge_with(item: DraggableItem) -> bool:
	return can_merge and item.id == id and item.rarity == rarity and rarity < Apeloot.Rarity.size() - 1

func increase_rarity() -> void:
	rarity = rarity + 1 as Apeloot.Rarity
	itemUpgraded.emit()
	Apeloot.item_updated.emit(parent_inventory, self)

func _on_item_upgraded():
	$GPUParticles2D.position = $ItemTexture.custom_minimum_size/2
	$GPUParticles2D.process_material.emission_sphere_radius = 30 * float(rarity)
	$GPUParticles2D.emitting = true

func end_drag():
	texture.end_drag()

func try_move_to_inventory(inv: GridInventory) -> bool:
	parent_inventory.deregister_item(self)
	if try_auto_stack(inv):
		queue_free()
		return true
	var placed = inv.try_fit_and_place(self)
	if not placed:
		parent_inventory.handle_item_drop(self, -1)
	return placed

func try_auto_stack(inv: GridInventory) -> bool:
	if not can_stack:
		return false
	var max_stack = Apeloot.items[id].stack
	for i in inv.items_node.get_children():
		if i.id == id:
			var can_deposit = max_stack - i.stack_count
			if can_deposit >= stack_count:
				i.stack_count += stack_count
				return true
			i.stack_count += can_deposit
			stack_count -= can_deposit
	return false
