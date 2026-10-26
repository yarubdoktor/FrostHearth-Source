extends RefCounted
## Original vector silhouettes: distinct type palette and equipment slot.
const TEXTURES := {
	"shield_weapon": preload("res://assets/gear/shield_weapon.svg"),
	"shield_armor": preload("res://assets/gear/shield_armor.svg"),
	"shield_helmet": preload("res://assets/gear/shield_helmet.svg"),
	"shield_rune": preload("res://assets/gear/shield_rune.svg"),
	"spear_weapon": preload("res://assets/gear/spear_weapon.svg"),
	"spear_armor": preload("res://assets/gear/spear_armor.svg"),
	"spear_helmet": preload("res://assets/gear/spear_helmet.svg"),
	"spear_rune": preload("res://assets/gear/spear_rune.svg"),
	"bow_weapon": preload("res://assets/gear/bow_weapon.svg"),
	"bow_armor": preload("res://assets/gear/bow_armor.svg"),
	"bow_helmet": preload("res://assets/gear/bow_helmet.svg"),
	"bow_rune": preload("res://assets/gear/bow_rune.svg"),
}


static func icon(tp: String, slot: String, side: int = 64) -> TextureRect:
	var view := TextureRect.new()
	view.name = "GearIcon_" + tp + "_" + slot
	view.texture = TEXTURES.get(tp + "_" + slot)
	view.custom_minimum_size = Vector2(side, side)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view
