extends Node3D

@onready var playerNode = get_node(".")


func _on_timer_timeout() -> void:
	print(playerNode)
	
	
