class_name EmberpanPauseInputRouter
extends Node

signal escape_pressed

var active := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process_input(true)


func _input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        escape_pressed.emit()
        get_viewport().set_input_as_handled()
