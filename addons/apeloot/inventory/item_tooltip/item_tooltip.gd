extends PanelContainer
class_name ItemTooltip

var item_ref: DraggableItem:
	set(val):
		item_ref = val
		update_props(val)

func update_props(item: DraggableItem):
	var item_data = Apeloot.items[item.id]
	self_modulate = Apeloot.rarities[item.rarity]["color"]
	%NameLabel.text = item_data["name"]
	%NameLabel.modulate = Apeloot.rarities[item.rarity]["color"]
	%DescLabel.text = item_data["desc"]
	%CountLabel.text = "x"+str(item.stack_count) if item.stack_count > 1 else ""
	%CountLabel.visible = item.stack_count > 1
