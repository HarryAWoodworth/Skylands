extends HBoxContainer

var heartFull = preload("res://assets/heartfull.png")
var heartEmpty = preload("res://assets/heartempty.png")

var currentHealth := 0
var topIndex: int

func _ready():
	topIndex = get_children().size()-1

func updateHealthBar(var health) -> void:
	if health < 0: health = 0
	print("Hello?")
	while health < topIndex+1:
		print("Removing health")
		removeHealth()
	while health > topIndex+1:
		print("Adding health. Health: ", health, " topIndex+1: ", topIndex+1)
		addHealth()

func removeHealth() -> void:
	if topIndex < 0: return
	get_children()[topIndex].setTexture(heartEmpty,false)
	topIndex-=1

func addHealth() -> void:
	topIndex+=1
	if topIndex > get_children().size()-1: return
	get_children()[topIndex].setTexture(heartFull,true)
