@tool
extends EditorPlugin
const AUTOLOAD_NAME = "Apeloot"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/apeloot/inventory/Apeloot.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
