extends GridInventory

func _ready():
	super._ready()
	item_placed.connect(trash_item)
	
func trash_item(item):
	remove_item(item)
