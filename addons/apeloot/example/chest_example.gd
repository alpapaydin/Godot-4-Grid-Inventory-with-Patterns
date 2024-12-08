extends GridInventory

func _ready():
	super._ready()
	var timer = Timer.new()
	timer.timeout.connect(spawn_items)
	timer.wait_time = 0.1
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
func spawn_items():
	var item = spawn_item("steak")
	snap_item_to_grid(item, 1)
