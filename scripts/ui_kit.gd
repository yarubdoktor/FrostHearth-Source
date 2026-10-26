extends RefCounted
## أدوات واجهة مشتركة (أنماط، أزرار، أيقونات) — نسخة فاخرة
## الأزرار متدرجة (توليد برمجي 9-slice) مع حدود لامعة وحالات ضغط واضحة

const FONT_PATH := "res://fonts/NotoKufiArabic.ttf"
const GOLD := Color("ffd36b")
const PANEL_BG := Color(0.05, 0.1, 0.17, 0.9)
const TEXT_DIM := Color("b9cbe0")
const RED := Color("ff8d80")
const GREEN := Color("8fe3a1")

static var _icons := {}
static var _tex_cache := {}

static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load("res://assets/ui/%s.png" % name)
	return _icons[name]

## ---------- توليد خامات متدرجة فاخرة (9-slice) ----------

## مسافة موقعة إلى مستطيل دائري الزوايا (سالب = داخل)
static func _sd_rounded(x: float, y: float, w: float, h: float, r: float) -> float:
	var px := x - w * 0.5
	var py := y - h * 0.5
	var qx := absf(px) - (w * 0.5 - r)
	var qy := absf(py) - (h * 0.5 - r)
	var ax := maxf(qx, 0.0)
	var ay := maxf(qy, 0.0)
	return minf(maxf(qx, qy), 0.0) + Vector2(ax, ay).length() - r

static func _grad_button_tex(top: Color, bottom: Color, border_col: Color) -> ImageTexture:
	var key := "%s|%s|%s" % [top.to_html(), bottom.to_html(), border_col.to_html()]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var S := 64          # حجم الخامة
	var M := 14.0        # هامش 9-slice (تُحفظ الزوايا كما هي)
	var R := 13.0        # نصف قطر الزاوية داخل الخامة
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := _sd_rounded(x + 0.5, y + 0.5, S, S, R)
			if d > 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t := float(y) / float(S - 1)
			var c := top.lerp(bottom, t)
			if d > -2.2:
				c = border_col            # ححد لامع حول الحافة
			elif y < 10:
				c = c.lightened(0.10)     # لمعة علوية خفيفة
			elif y > S - 6:
				c = c.darkened(0.10)     # ظل سفلي خفيف
			var a: float = clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func _tex_style(tex: ImageTexture, pad_h: int = 18, pad_v: int = 8) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(14)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

## ---------- أنماط مسطحة (لوحات وشرائح) ----------

static func style(bg: Color, radius: int = 14, border: Color = Color(1, 1, 1, 0.14), pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad - 4
	s.content_margin_bottom = pad - 4
	s.border_color = border
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = load(FONT_PATH)
	th.default_font_size = 20
	return th

## ---------- أزرار فاخرة ----------

static func button(text: String, cb: Callable, kind: String = "dark", h: int = 54) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	# [أعلى، أسفل، لون النص، لون الحد]
	var cols := {"dark": [Color("32415c"), Color("1a2740"), Color.WHITE, Color(1, 1, 1, 0.22)],
			"gold": [Color("f4c065"), Color("bd7c22"), Color("241505"), Color("ffe8b0")],
			"blue": [Color("4d9ce6"), Color("235eb4"), Color.WHITE, Color(1, 1, 1, 0.28)],
			"red": [Color("e06a5f"), Color("a3332e"), Color.WHITE, Color(1, 1, 1, 0.28)],
			"green": [Color("5cc47e"), Color("2a8149"), Color("04140a"), Color(1, 1, 1, 0.28)]}
	var c: Array = cols.get(kind, cols["dark"])
	var top: Color = c[0]
	var bot: Color = c[1]
	var txt: Color = c[2]
	var bd: Color = c[3]
	b.add_theme_stylebox_override("normal", _tex_style(_grad_button_tex(top, bot, bd)))
	b.add_theme_stylebox_override("hover", _tex_style(_grad_button_tex(top.lightened(0.12), bot.lightened(0.10), bd.lightened(0.4))))
	b.add_theme_stylebox_override("pressed", _tex_style(_grad_button_tex(bot.darkened(0.12), bot.darkened(0.26), bd.darkened(0.4))))
	b.add_theme_stylebox_override("disabled", _tex_style(_grad_button_tex(Color(0.27, 0.30, 0.35), Color(0.19, 0.22, 0.27), Color(1, 1, 1, 0.08))))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, txt)
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.65, 0.70))
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: Sound.ui_click())
	return b

static func label(text: String, size: int = 20, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func icon_rect(name: String, size: int = 30) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## شريحة: أيقونة + نص (تُرجع [الحاوية، النص])
static func chip(icon_name: String, size: int = 30, font: int = 19) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(Color(0.06, 0.11, 0.19, 0.85), 22, Color(1, 1, 1, 0.16), 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(icon_rect(icon_name, size))
	var l := label("", font, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	h.add_child(l)
	return [p, l]

static func power_bar(width: float = 230.0) -> Array:
	## عداد القوة الموحّد (المدينة + الخارج): شريط عريض بحد ذهبي — أيقونة سيوف • الرقم • عنوان صغير.
	var p := PanelContainer.new()
	p.name = "PowerBar"
	p.custom_minimum_size = Vector2(width, 0)
	p.add_theme_stylebox_override("panel", style(Color(0.12, 0.09, 0.05, 0.92), 22, Color("e8b44a", 0.85), 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(icon_rect("army", 32))
	var l := label("", 26, Color("fff1cf"), HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(label("القوة", 15, Color("e8c98a"), HORIZONTAL_ALIGNMENT_RIGHT))
	return [p, l]

static func panel(bg: Color = PANEL_BG, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, Color(1, 1, 1, 0.16), 14))
	return p

static func progress_bar(color: Color = Color("4fb4ff")) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(6)
	bg.border_color = Color(1, 1, 1, 0.12)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(6)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb
