extends Node
## مدير الصوت — أوتولود مستقل عن منطق اللعبة: النواقل والتشغيل والإعدادات.
## يستمع لإشارات Game ولا يستدعي منطق اللعب — الفصل مقصود حتى يبقى الاختبار آليًا سهلًا.
## قاعدة مهمة: أثناء محاكاة الغياب (تحميل اللعبة) لا يُشغَّل أي صوت (Game._offline).

const CFG_PATH := "user://audio.cfg"
const MAX_VOL := 10.0
const WIND_BASE := 0.30     # هدوء
const WIND_STORM := 0.85     # عاصفة

signal volumes_changed   # تغيّرت المستويات — لتحديث الواجهة

var cfg_path_override := ""    # مسار بديل للاختبارات حتى لا تُمس إعدادات اللاعب
var music_vol := 8.0            # 0 صامت .. 10
var sfx_vol := 8.0              # 0 صامت .. 10 (الرياح تتبع المؤثرات)
var play_count := 0             # عداد التشغيل — للاختبارات
var last_played := ""           # آخر صوت شُغّل — للاختبارات

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _alert_p: AudioStreamPlayer
var _storm := false
var _poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_streams()
	_load_cfg()
	_apply_bus_volumes()
	_setup_players()
	_connect_game()
	_update_wind()


# ---------------------------------------------------------------- الإعداد
func _setup_buses() -> void:
	## ثلاثة نواقل: موسيقى / أجواء (رياح) / مؤثرات — كلها تصب في Master
	for bus_name in ["Music", "Ambience", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _load_streams() -> void:
	## تحميل كل الأصوات مرة واحدة عند الإقلاع — res://assets/audio/
	var paths := {
		"click": "res://assets/audio/click.wav",
		"collect": "res://assets/audio/collect.wav",
		"build": "res://assets/audio/build.wav",
		"march": "res://assets/audio/march.wav",
		"victory": "res://assets/audio/victory.wav",
		"defeat": "res://assets/audio/defeat.wav",
		"alert": "res://assets/audio/alert.wav",
		"storm": "res://assets/audio/storm.wav",
		"wind": "res://assets/audio/wind.ogg",
		"music": "res://assets/audio/music.ogg",
	}
	for k in paths:
		var s: AudioStream = load(paths[k])
		if s != null:
			_streams[k] = s


func _setup_players() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_wind = AudioStreamPlayer.new()
	_wind.bus = "Ambience"
	add_child(_wind)
	_alert_p = AudioStreamPlayer.new()   # قناة إنذار مستقلة — لا يقطعها نقرة زر
	_alert_p.bus = "SFX"
	add_child(_alert_p)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	if _streams.has("wind"):
		_enable_loop(_streams["wind"])
		_wind.stream = _streams["wind"]
		_wind.play()
	if _streams.has("music"):
		_enable_loop(_streams["music"])
		_music.stream = _streams["music"]
		if music_vol > 0.0:
			_music.play()


func _enable_loop(s: AudioStream) -> void:
	## تفعيل التكرار برمجيًا — لا نعتمد على إعدادات الاستيراد
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2   # أحادي 16-bit


func _connect_game() -> void:
	## الاستماع لأحداث اللعب — لا صوت أثناء محاكاة الغياب
	Game.building_done.connect(_on_building_done)
	Game.march_done.connect(_on_march_done)
	Game.venture_done.connect(_on_venture_done)
	Game.raid_happened.connect(_on_raid)
	Game.storm_changed.connect(_on_storm)


func _process(delta: float) -> void:
	## استطلاع خفيف لحالة العاصفة (تغطية تغيّرها أثناء تحميل اللعبة)
	_poll += delta
	if _poll >= 2.0:
		_poll = 0.0
		var active := Game.storm_active()
		if active != _storm:
			_storm = active
			_update_wind()


# ---------------------------------------------------------------- التشغيل
func play(name: String) -> void:
	## تشغيل مؤثر من المجموعة الدوّارة (4 قنوات تكفي للهاتف)
	var s: AudioStream = _streams.get(name)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.play()
	play_count += 1
	last_played = name


func play_alert(name: String) -> void:
	## أصوات الإنذار على قناة مستقلة — النقر لا يقطعها
	var s: AudioStream = _streams.get(name)
	if s == null:
		return
	_alert_p.stream = s
	_alert_p.play()
	play_count += 1
	last_played = name


func ui_click() -> void:
	play("click")


func _update_wind() -> void:
	## شدة الرياح تتبع الطقس — والمستوى يبقى مضروبًا بإعداد المستخدم (لا يلغيه)
	if _wind == null:
		return
	var gain := WIND_STORM if _storm else WIND_BASE
	_wind.volume_db = linear_to_db(gain)


# ---------------------------------------------------------------- الإعدادات
func set_music_vol(v: float) -> void:
	music_vol = clampf(v, 0.0, MAX_VOL)
	_apply_bus_volumes()
	if music_vol <= 0.0:
		_music.stop()
	elif not _music.playing:
		_music.play()
	save_cfg()
	volumes_changed.emit()


func set_sfx_vol(v: float) -> void:
	sfx_vol = clampf(v, 0.0, MAX_VOL)
	_apply_bus_volumes()
	save_cfg()
	volumes_changed.emit()


func _apply_bus_volumes() -> void:
	## 0 تعني صمتًا تامًا (dB = -inf)
	var m := AudioServer.get_bus_index("Music")
	var a := AudioServer.get_bus_index("Ambience")
	var s := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(m, linear_to_db(music_vol / MAX_VOL))
	AudioServer.set_bus_volume_db(a, linear_to_db(sfx_vol / MAX_VOL))
	AudioServer.set_bus_volume_db(s, linear_to_db(sfx_vol / MAX_VOL))


func _cfg_path() -> String:
	return cfg_path_override if cfg_path_override != "" else CFG_PATH


func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music_vol)
	c.set_value("audio", "sfx", sfx_vol)
	c.save(_cfg_path())


func _load_cfg() -> void:
	## قراءة الإعدادات مع تحمل الملف التالف أو الناقص — القيم الافتراضية عند الشك
	var c := ConfigFile.new()
	if c.load(_cfg_path()) != OK:
		return
	music_vol = _cfg_num(c, "music", music_vol)
	sfx_vol = _cfg_num(c, "sfx", sfx_vol)


func _cfg_num(c: ConfigFile, key: String, fallback: float) -> float:
	var v = c.get_value("audio", key, fallback)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return fallback
	return clampf(float(v), 0.0, MAX_VOL)


# ---------------------------------------------------------------- أحداث اللعب
func _on_building_done(_id: String) -> void:
	if not Game._offline:
		play("build")


func _on_march_done(_m: Dictionary) -> void:
	if not Game._offline:
		play("collect")


func _on_venture_done(rep: Dictionary) -> void:
	if Game._offline:
		return
	play("victory" if bool(rep.get("win", false)) else "defeat")


func _on_raid(_report: Dictionary) -> void:
	if not Game._offline:
		play_alert("alert")


func _on_storm(active: bool) -> void:
	_storm = active
	_update_wind()
	if active and not Game._offline:
		play_alert("storm")
