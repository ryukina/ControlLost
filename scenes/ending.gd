extends Control


const ZH_FONT = preload("res://resources/fonts/ending-zh.tres")
func _ready():
	if Global.is_chinese():
		$Dialog/Content.add_font_override("font", ZH_FONT)
	yield(get_tree().create_timer(1.0), "timeout")
	yield(NodeTransform.fade_in($title, 0.5), "transformed")
	NodeTransform.fade_in($bg, 1.0)
	yield(NodeTransform.fade_in($credits, 2), "transformed")
	$Dialog.type(tr("THANKS"))
	yield($Dialog, "typing_completed")
	$icon.show()
	ready = true


var ready = false
func _on_Background_pressed():
	if ready:
		ready = false
		SFX.play(SFX.GENERAL_UI_01)
		Global.goto_scene("res://scenes/title.tscn")
