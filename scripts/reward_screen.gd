extends Node2D

signal confirmed(option_index: int)

var _selected := 0 # 0 = left, 1 = right

@onready var opt_one := $OptionOne
@onready var opt_two := $OptionTwo
@onready var select_one := $OptionOne/OptionSelect as ColorRect
@onready var select_two := $OptionTwo/OptionSelect as ColorRect
@onready var confirm_btn := $Button as Button

func _ready() -> void:
	# pause_mode = Node.PAUSE_MODE_PROCESS
	_apply_selection_visuals()
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_selected = 0
		_apply_selection_visuals()
	elif event.is_action_pressed("move_right"):
		_selected = 1
		_apply_selection_visuals()
	elif event.is_action_pressed("ui_accept"):
		_on_confirm_pressed()

func _apply_selection_visuals() -> void:
	if select_one: select_one.visible = (_selected == 0)
	if select_two: select_two.visible = (_selected == 1)

func _on_confirm_pressed() -> void:
	confirmed.emit(_selected)
	queue_free()
