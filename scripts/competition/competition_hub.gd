extends Control
## Competition hub preview. The existing city and save system are untouched.
const Adapter := preload("res://scripts/competition/competition_local_adapter.gd")
const MatchModel := preload("res://scripts/competition/competition_match.gd")
const BG := Color("#07111f")
const GOLD := Color("#f3c86a")
const TEXT := Color("#f1f5fa")
const MUTED := Color("#9db0c6")
var profile_label: Label
var status_label: Label
var seats_label: Label
var preview_match: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_right = -16
	scroll.offset_top = 16
	scroll.offset_bottom = -16
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var back := _button("العودة إلى المدينة", false)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://city.tscn"))
	header.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("ميدان المنافسة", 28, GOLD))
	var panel := _panel()
	content.add_child(panel)
	var hero := VBoxContainer.new()
	panel.add_child(hero)
	hero.add_child(_label("عهد الفرسان", 24, TEXT))
	hero.add_child(_label("تأهل في مباراة من أربع مدن، ثم نافس على مبنى الملك.", 16, MUTED))
	profile_label = _label("جارٍ قراءة ملف القائد…", 17, TEXT)
	hero.add_child(profile_label)
	status_label = _label("وضع محلي تجريبي — لا يوجد اتصال بخادم", 14, GOLD)
	hero.add_child(status_label)
	var qualifier := _panel()
	content.add_child(qualifier)
	var qbox := VBoxContainer.new()
	qualifier.add_child(qbox)
	qbox.add_child(_label("01 • مباريات التأهل", 22, GOLD))
	qbox.add_child(_label("أربع مدن في المباراة. النتائج هنا معاينة فقط ولا تمنح نقاطاً أو مكافآت.", 15, TEXT))
	seats_label = _label("مقاعد المعاينة: 0 من 4", 16, MUTED)
	qbox.add_child(seats_label)
	var preview := _button("إنشاء معاينة محلية", true)
	preview.pressed.connect(_make_preview)
	qbox.add_child(preview)
	var arena := _button("فتح مخطط ساحات المنافسة", false)
	arena.pressed.connect(func(): get_tree().change_scene_to_file("res://competition_arena_preview.tscn"))
	qbox.add_child(arena)
	var king := _panel()
	content.add_child(king)
	var kbox := VBoxContainer.new()
	king.add_child(kbox)
	kbox.add_child(_label("02 • مبنى الملك", 22, GOLD))
	kbox.add_child(_label("المخطط المستقبلي مقسّم إلى 25 قطاعاً، بسعة تصميمية تصل إلى 100 لاعب.", 15, TEXT))
	kbox.add_child(_label("غير مفعّل: يحتاج قتالاً موثوقاً وخادماً لاحقاً.", 14, MUTED))
	var ranking := _panel()
	content.add_child(ranking)
	var rbox := VBoxContainer.new()
	ranking.add_child(rbox)
	rbox.add_child(_label("03 • ترتيب الموسم", 22, GOLD))
	rbox.add_child(_label("لا يوجد ترتيب عالمي أو مكافآت فعلية قبل تنفيذ الخادم والتحقق من النتائج.", 15, TEXT))
	_refresh_profile()

func _refresh_profile() -> void:
	var record: Dictionary = Adapter.build_from_game()
	var player: Dictionary = record.get("player", {})
	if player.is_empty():
		profile_label.text = "تعذر قراءة ملف القائد المحلي."
		return
	profile_label.text = "%s • القوة %s • مستوى المدينة %d" % [str(player.get("display_name", "قائد")), str(player.get("power", 0)), int(player.get("city_level", 0))]

func _make_preview() -> void:
	var record: Dictionary = Adapter.build_from_game()
	var player: Dictionary = record.get("player", {})
	if player.is_empty():
		status_label.text = "تعذر إنشاء المعاينة: ملف القائد غير جاهز."
		return
	preview_match = MatchModel.create_match("local-preview-%d" % Time.get_ticks_msec(), "preview-season", int(Time.get_unix_time_from_system()))
	preview_match = MatchModel.add_player(preview_match, player)
	seats_label.text = "مقاعد المعاينة: %d من 4" % preview_match.get("players", []).size()
	status_label.text = "معاينة محلية فقط — لا اتصال بالشبكة ولا تغيير في الحفظ."

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101f31")
	style.border_color = Color("#34465b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT if not emphasized else Color("#17202b"))
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD if emphasized else Color("#172a40")
	style.border_color = GOLD if emphasized else Color("#52657b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	return button
