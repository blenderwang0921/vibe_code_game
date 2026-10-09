extends CanvasLayer

const GOLD := Color("e5c794")
const TEXT := Color("f0eadb")
const MUTED := Color("a6b7b5")
const MINT := Color("a6d9c3")
var world
var root: Control
var health_label: Label
var health_note: Label
var health_bar: ProgressBar
var quest_label: Label
var quest_detail: Label
var quest_bar: ProgressBar
var zone_label: Label
var interact_label: Label
var fire_label: Label
var frost_label: Label
var fire_title: Label
var frost_title: Label
var fire_bar: ProgressBar
var frost_bar: ProgressBar
var fire_icon: TextureRect
var frost_icon: TextureRect
var toast: Panel
var toast_label: Label
var toast_left: float = 0.0
var modal: Control
var modal_kind: String = ""
var modal_panel: Panel
var modal_title: Label
var modal_detail: Label
var modal_buttons: Control
var fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = LowPoly.font()
	theme.default_font_size = 17
	root.theme = theme
	add_child(root)
	var overlay := Control.new()
	overlay.set_script(preload("res://scripts/world_overlay.gd"))
	overlay.name = "EnemyBars"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	_label(root, "暮光林地", Rect2(26, 21, 300, 44), 31, TEXT)
	_label(root, "小巫師的第一課", Rect2(28, 64, 280, 24), 15, GOLD)
	var quest := _panel(root, Vector2(1, 0), Vector2(-326, 24), Vector2(300, 146))
	quest_label = _label(quest, "護林人的委託", Rect2(18, 12, 264, 28), 20, GOLD)
	quest_detail = _label(quest, "", Rect2(18, 47, 264, 67), 16, TEXT)
	quest_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_bar = _bar(quest, Rect2(18, 125, 264, 4), MINT)
	var zone := _panel(root, Vector2(0.5, 0), Vector2(-105, 25), Vector2(210, 34))
	zone_label = _label(zone, "", Rect2(0, 0, 210, 34), 14, MINT)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hp := _panel(root, Vector2(0, 1), Vector2(24, -119), Vector2(246, 89))
	_label(hp, "見習巫師", Rect2(16, 10, 115, 24), 16, TEXT)
	health_label = _label(hp, "100 / 100", Rect2(116, 10, 114, 24), 17, MINT)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_bar = _bar(hp, Rect2(16, 42, 214, 8), MINT)
	health_note = _label(hp, "", Rect2(16, 56, 214, 20), 12, MUTED)
	var fire := _spell_panel(Vector2(-193, -119), "Q", "火球", preload("res://assets/fire.svg"), Color("f4ae83"))
	fire_label = fire.status
	fire_bar = fire.bar
	fire_title = fire.title
	fire_icon = fire.icon
	var frost := _spell_panel(Vector2(7, -119), "W", "冰霜", preload("res://assets/frost.svg"), Color("a1e9eb"))
	frost_label = frost.status
	frost_bar = frost.bar
	frost_title = frost.title
	frost_icon = frost.icon
	var map_panel := _panel(root, Vector2(1, 1), Vector2(-190, -228), Vector2(166, 198))
	_label(map_panel, "林地指南", Rect2(12, 7, 142, 23), 14, GOLD)
	var minimap := Control.new()
	minimap.set_script(preload("res://scripts/minimap.gd"))
	minimap.name = "Minimap"
	minimap.position = Vector2(4, 31)
	minimap.size = Vector2(158, 163)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(minimap)
	map_panel.name = "MapPanel"
	interact_label = _label(root, "", Rect2(0, 0, 700, 28), 17, GOLD)
	_anchor(interact_label, Vector2(0.5, 1), Vector2(-350, -165), Vector2(700, 28))
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var guide := _label(root, "右鍵 移動     Q / W 施法     E 交談     Esc 暫停", Rect2(0, 0, 600, 22), 12, MUTED)
	_anchor(guide, Vector2(0.5, 1), Vector2(-300, -25), Vector2(600, 22))
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _panel(root, Vector2(0.5, 0), Vector2(-300, 86), Vector2(600, 72))
	toast_label = _label(toast, "", Rect2(16, 5, 568, 62), 16, TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.hide()
	fps_label = _label(root, "", Rect2(26, 96, 210, 18), 11, MUTED)
	_build_modal()

func bind_world(value) -> void:
	world = value
	root.get_node("EnemyBars").world = world
	root.get_node("MapPanel/Minimap").world = world

func _panel(parent: Control, anchor: Vector2, offset: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.067, 0.12, 0.15, 0.94), Color("52615d")))
	parent.add_child(panel)
	_anchor(panel, anchor, offset, dimensions)
	return panel

func _anchor(item: Control, anchor: Vector2, offset: Vector2, dimensions: Vector2) -> void:
	item.anchor_left = anchor.x
	item.anchor_right = anchor.x
	item.anchor_top = anchor.y
	item.anchor_bottom = anchor.y
	item.offset_left = offset.x
	item.offset_top = offset.y
	item.offset_right = offset.x + dimensions.x
	item.offset_bottom = offset.y + dimensions.y

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("304643")
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = rect.size
	return bar

func _spell_panel(offset: Vector2, key: String, title: String, texture: Texture2D, color: Color) -> Dictionary:
	var panel := _panel(root, Vector2(0.5, 1), offset, Vector2(186, 89))
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(14, 15)
	icon.size = Vector2(43, 43)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var name_label := _label(panel, key + "  " + title, Rect2(67, 12, 110, 27), 20, color)
	var status := _label(panel, "就緒", Rect2(67, 43, 110, 22), 13, MUTED)
	var bar := _bar(panel, Rect2(14, 74, 158, 4), color)
	return {"title": name_label, "status": status, "bar": bar, "icon": icon}

func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.075, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_panel = _panel(modal, Vector2(0.5, 0.5), Vector2(-330, -222), Vector2(660, 444))
	modal_title = _label(modal_panel, "", Rect2(32, 27, 596, 46), 30, GOLD)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_detail = _label(modal_panel, "", Rect2(36, 92, 588, 190), 18, TEXT)
	modal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	modal_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_buttons = Control.new()
	modal_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_panel.add_child(modal_buttons)
	modal.hide()

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(Color("284448"), Color("8a9b7e")))
	button.add_theme_stylebox_override("hover", _style(Color("3b605b"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("233b40"), GOLD))
	button.pressed.connect(callback)
	modal_buttons.add_child(button)
	return button

func show_modal(kind: String) -> void:
	modal_kind = kind
	for child in modal_buttons.get_children():
		child.queue_free()
	modal.show()
	get_tree().paused = true
	match kind:
		"pause":
			modal_title.text = "在林間歇一會兒"
			modal_detail.text = "右鍵點地面：移動，會自動繞過樹木與石頭\nQ 火球：朝游標方向施放，碰到障礙會消失\nW 冰霜：游標處範圍傷害與減速，射程 %d 公尺\nE：靠近護林人接取或回報委託\n邊走邊施法；回到村莊可恢復生命。" % world.balance.frost_range
			_button("繼續旅程  ·  Esc", Rect2(36, 333, 285, 66), close_modal)
			_button("降低特效：" + ("開" if world.low_effects else "關"), Rect2(337, 333, 287, 66), func():
				world.set_low_effects(not world.low_effects)
				show_modal("pause"))
		"reward":
			modal_title.text = "第一道魔法的進階"
			modal_detail.text = "「森林終於安靜下來了。\n選一道你喜歡的魔法，我來教你。」\n\n委託完成・擊敗 %d 隻苔背獸\n本次旅程可選擇一項，立即生效。" % world.state.target
			_button("1  熾焰\n火球傷害 +%d%%" % roundi((world.balance.fire_upgrade_multiplier - 1.0) * 100), Rect2(36, 315, 285, 92), func(): world.claim_reward(&"fire"))
			_button("2  凜冬\n冰霜半徑 +%d%%" % roundi((world.balance.frost_upgrade_multiplier - 1.0) * 100), Rect2(337, 315, 287, 92), func(): world.claim_reward(&"frost"))
		"dead":
			modal_title.text = "星光暫歇"
			modal_detail.text = "你在森林中失去了意識。\n\n用冰霜拉開距離，再用火球反擊。\n看到苔背獸腳下的橙色圓環，就快躲開！\n\n重試會重置任務、怪物與法術強化。"
			_button("重新出發  ·  R", Rect2(170, 333, 320, 66), func(): world.restart())

func close_modal() -> void:
	modal_kind = ""
	modal.hide()
	get_tree().paused = false

func notify(message: String, duration: float = 3.0) -> void:
	toast_label.text = message
	toast_left = duration
	toast.show()

func _unhandled_input(event: InputEvent) -> void:
	if world == null or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		if modal_kind == "dead":
			return
		if modal_kind == "":
			show_modal("pause")
		else:
			close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and modal_kind == "dead":
		get_viewport().set_input_as_handled()
		world.restart()
	elif modal_kind == "reward":
		if event.is_action_pressed("reward_fire"):
			world.claim_reward(&"fire")
		elif event.is_action_pressed("reward_frost"):
			world.claim_reward(&"frost")

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world.player):
		return
	toast_left = maxf(0, toast_left - delta)
	toast.visible = toast_left > 0.0
	var player: WizardPlayer = world.player
	health_label.text = "%d / %d" % [ceili(player.health.current), player.health.maximum]
	health_bar.value = player.health.current / player.health.maximum * 100
	var safe: bool = world.is_safe(player.global_position)
	zone_label.text = "◆  榆木村  ·  安全區" if safe else "◇  暮光森林  ·  戰鬥區"
	health_note.text = "結界庇護・生命恢復中" if safe else "保持移動，留意敵人的攻擊預兆"
	fire_label.text = "%.1f 秒" % player.spells.fire_left if player.spells.fire_left > 0 else "就緒  ·  傷害 %d" % player.spells.fire_damage()
	frost_label.text = "%.1f 秒" % player.spells.frost_left if player.spells.frost_left > 0 else "就緒  ·  半徑 %.1f" % player.spells.frost_radius()
	fire_bar.value = (1.0 - player.spells.fire_left / world.balance.fire_cooldown) * 100
	frost_bar.value = (1.0 - player.spells.frost_left / world.balance.frost_cooldown) * 100
	fire_icon.modulate.a = 0.4 if player.spells.fire_left > 0.0 else 1.0
	frost_icon.modulate.a = 0.4 if player.spells.frost_left > 0.0 else 1.0
	fire_title.text = "Q  熾焰" if world.state.reward == &"fire" else "Q  火球"
	frost_title.text = "W  凜冬" if world.state.reward == &"frost" else "W  冰霜"
	quest_bar.value = float(world.state.kills) / world.state.target * 100
	match world.state.quest:
		RunState.Quest.AVAILABLE:
			quest_detail.text = "森林裡傳來奇怪的聲響……\n靠近榆木，按 E 接下委託。"
		RunState.Quest.ACTIVE:
			quest_detail.text = "驅散苔背獸    %d / %d\n沿小徑穿過結界，進入森林。" % [world.state.kills, world.state.target]
		RunState.Quest.READY:
			quest_detail.text = "驅散苔背獸    %d / %d  ✓\n返回村莊，找榆木領取強化。" % [world.state.kills, world.state.target]
		RunState.Quest.REWARDED:
			quest_detail.text = "委託完成  ✓\n新魔法已習得，繼續探索森林。"
	var near := player.global_position.distance_to(world.elder.global_position) <= 3.2
	interact_label.text = "E  與護林人・榆木交談" if near else ("回村找榆木，領取你的法術強化 ↓" if world.state.quest == RunState.Quest.READY else "")
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

