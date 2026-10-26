extends RefCounted
## وحدة نافذة المطور — بلا حالة، المدينة تفوّض إليها

const UI := preload("res://scripts/ui_kit.gd")


static func dev_window(city: Node) -> void:
	## نافذة نظام المطور: كلمة سر أو أدوات إذا كان الوضع مفعلاً
	city._close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	city.modal_layer.add_child(dim)
	var p := UI.panel(Color(0.06, 0.11, 0.19, 0.97), 22)
	p.custom_minimum_size = Vector2(480, 0)
	dim.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label("نظام المطور", 26, UI.GOLD))
	if Game.dev_mode:
		v.add_child(UI.label("وضع المطور مفعّل: كل التكاليف والاشتراطات مُتجاوزة.\nيظهر زر الأدوات أسفل اليمين.", 18))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		v.add_child(hb)
		hb.add_child(UI.button("أدوات المطور", func():
			dim.queue_free()
			dev_panel(city), "blue"))
		hb.add_child(UI.button("إيقاف الوضع", func():
			Game.try_dev_mode(Game.DEV_PASSWORD)
			dim.queue_free(), "red"))
		hb.add_child(UI.button("إغلاق", func(): dim.queue_free(), "dark"))
	else:
		v.add_child(UI.label("أدخل كلمة سر المطور:", 18))
		var edit := LineEdit.new()
		edit.secret = true
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.custom_minimum_size = Vector2(0, 52)
		v.add_child(edit)
		var try_login := func():
			if Game.try_dev_mode(edit.text):
				dim.queue_free()
				dev_panel(city)
			else:
				city._toast("كلمة السر غير صحيحة")
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		v.add_child(hb)
		hb.add_child(UI.button("دخول", try_login, "blue"))
		hb.add_child(UI.button("إغلاق", func(): dim.queue_free(), "dark"))
		edit.text_submitted.connect(func(_t: String): try_login.call())


static func dev_panel(city: Node) -> void:
	## أدوات المطور: تجربة سريعة دون مساس بأنظمة اللعب للآخرين
	city._close_panel()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	city.modal_layer.add_child(dim)
	var p := UI.panel(Color(0.06, 0.11, 0.19, 0.97), 22)
	p.custom_minimum_size = Vector2(480, 0)
	dim.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("أدوات المطور", 26, UI.GOLD))
	var tools: Array = [
		["+100 ألف لكل مورد", func(): Game.dev_give_resources()],
		["+1000 جوهرة و+1000 بلورة", func(): Game.dev_give_premium()],
		["+50 ساكن", func(): Game.dev_add_pop(50)],
		["تسريع كل شيء (بناء وتدريب وبحث)", func(): Game.dev_finish_all()],
		["علاج الجرحى والمرضى", func(): Game.dev_heal_all()],
		["كشف الخريطة كلها (ضباب الحرب)", func(): Game.dev_reveal_map()],
	]
	for i in tools:
		v.add_child(UI.button(String(i[0]), func(): i[1].call(); city._toast("تم"), "blue"))
	v.add_child(UI.button("إغلاق", func(): dim.queue_free(), "dark"))


static func confirm_reset(city: Node) -> void:
	city._modal("تأكيد", "سيتم حذف تقدمك بالكامل وبدء مدينة جديدة. هل أنت متأكد؟",
		[["تراجع", func(): pass, "dark"], ["نعم، احذف", func():
			Game.reset_game()
			city.get_tree().reload_current_scene(), "red"]])


