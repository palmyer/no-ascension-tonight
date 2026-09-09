extends CanvasLayer

## Three-choice level-up screen. The card is intentionally a decision surface,
## not a text dump: rank, next-step value, route, and play pattern are visible
## before the player commits.

const RARITY_NAMES := {
	"common": "常见",
	"uncommon": "稀有",
	"rare": "秘藏"
}

const RARITY_COLORS := {
	"common": Color("b7c4d1"),
	"uncommon": Color("62d5b0"),
	"rare": Color("e9b45e")
}

const STAT_NAMES := {
	"max_health": "最大生命",
	"damage_pct": "攻击伤害",
	"move_speed": "移动速度",
	"armor": "减伤护甲",
	"attack_speed": "攻击速度",
	"bullet_count": "额外弹道",
	"hp_regen_5s": "五秒回复",
	"attack_range": "攻击范围",
	"pickup_range": "拾取范围"
}

const ATTRIBUTE_NAMES := {
	"fire": "火",
	"blast": "爆",
	"poison": "毒",
	"vine": "藤",
	"water": "水",
	"ice": "冰",
	"wind": "风",
	"thunder": "雷"
}

const CARD_ICONS := {
	"stat_max_health": "体",
	"stat_damage": "锋",
	"stat_speed": "步",
	"stat_armor": "骨",
	"stat_attack_speed": "迅",
	"stat_bullet_count": "符",
	"stat_regen": "回",
	"stat_attack_range": "域",
	"stat_pickup_range": "摄",
	"attribute_fire": "火",
	"attribute_blast": "爆",
	"attribute_poison": "毒",
	"attribute_vine": "藤",
	"attribute_water": "水",
	"attribute_ice": "冰",
	"attribute_wind": "风",
	"attribute_thunder": "雷",
	"reaction_overload": "应",
	"chain_echo": "链",
	"special_aftershock": "震",
	"special_core_repair": "愈",
	"special_radius": "环",
	"core_revenge": "怒",
	"core_guardian": "守",
	"aura_slow": "缚",
	"far_hunt": "猎",
	"spirit_harvest": "收",
	"attribute_shift": "转",
	"attribute_prism": "棱",
	"critical_edge": "暴",
	"critical_explosion": "爆",
	"reaction_overflow": "溢",
	"status_detonator": "蚀",
	"momentum_edge": "势",
	"orb_alchemy": "炼",
	"rainbow_confluence": "虹",
	"aura_forge": "铸",
	"low_health_frenzy": "残",
	"boss_hunter": "妖",
	"execution_burst": "断",
	"overkill_conversion": "余",
	"overkill_split": "分",
	"aegis_resonance": "盾",
	"shield_breaker": "震",
	"shield_revenge": "返",
	"afterimage": "影",
	"afterimage_echo": "映",
	"afterimage_return": "归",
	"fracture_mark": "脉",
	"fracture_harvest": "收",
	"attribute_overload": "载",
	"attribute_overload_echo": "温",
	"returning_edge": "回",
	"return_double": "锋",
	"kill_rhythm": "律",
	"kill_chain": "魂",
	"damage_alchemy": "淬",
	"damage_transmute": "炼",
	"sword_sweep": "斩",
	"sword_burn_trail": "焰",
	"blade_combo": "连",
	"blade_poison_cloud": "瘴",
	"spear_pierce": "贯",
	"spear_shatter": "裂",
	"musket_charge": "蓄",
	"musket_aura": "曜"
}

const WEAPON_NAMES := {
	"sword": "引霜灵剑",
	"blade": "破鳞钢刃",
	"spear": "龙脊长枪",
	"musket": "天工灵铳"
}

var card_container: HBoxContainer
var level_label: Label
var footer_label: Label
var current_offer: Array[Dictionary] = []
var selecting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	card_container = get_node_or_null("Control/HBoxContainer") as HBoxContainer
	level_label = get_node_or_null("Control/Subtitle") as Label
	footer_label = get_node_or_null("Control/Footer") as Label
	if not EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.connect(_on_level_up)
	if card_container:
		card_container.add_theme_constant_override("separation", 22)


func _on_level_up(new_level: int) -> void:
	if not card_container:
		return
	visible = true
	selecting = true
	get_tree().paused = true
	if level_label:
		level_label.text = "第 %d 次突破  ·  选择一张卡，构筑会永久保留" % maxi(new_level - 1, 1)
	if footer_label:
		footer_label.text = "按 1 / 2 / 3 选择  ·  鼠标悬停查看高亮  ·  选择后继续战斗"
	for child in card_container.get_children():
		child.queue_free()

	current_offer = UpgradeManager.get_offer(3)
	if current_offer.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前构筑已达到上限"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color("f2e5bf"))
		empty_label.custom_minimum_size = Vector2(720, 120)
		card_container.add_child(empty_label)
		return

	for index in range(current_offer.size()):
		var button := _build_card(current_offer[index], index)
		card_container.add_child(button)
		button.pressed.connect(_on_card_selected.bind(current_offer[index]))

	var first_card := card_container.get_child(0) as Button
	if first_card:
		first_card.grab_focus()


func _build_card(card: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Card_%d" % (index + 1)
	button.custom_minimum_size = Vector2(356, 500)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _description_text(card)
	var accent: Color = _card_accent(card)
	button.add_theme_stylebox_override("normal", _make_card_style(accent, 0.12, 1))
	button.add_theme_stylebox_override("hover", _make_card_style(accent, 0.26, 2))
	button.add_theme_stylebox_override("pressed", _make_card_style(accent, 0.38, 3))
	button.add_theme_stylebox_override("focus", _make_card_style(accent, 0.30, 2))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 24.0
	content.offset_top = 20.0
	content.offset_right = -24.0
	content.offset_bottom = -20.0
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 34)
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	var index_badge := Label.new()
	index_badge.text = "  %d  " % (index + 1)
	index_badge.add_theme_font_size_override("font_size", 15)
	index_badge.add_theme_color_override("font_color", Color("07141b"))
	index_badge.add_theme_stylebox_override("normal", _make_badge_style(accent))
	index_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(index_badge)
	var rarity_label := Label.new()
	rarity_label.text = "%s  ·  %s" % [RARITY_NAMES.get(str(card.get("rarity", "common")), "常见"), str(card.get("category", "成长"))]
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.add_theme_color_override("font_color", accent)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(rarity_label)

	var icon := Label.new()
	icon.text = str(CARD_ICONS.get(str(card.get("id", "")), "✦"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(0, 74)
	icon.add_theme_font_size_override("font_size", 52)
	icon.add_theme_color_override("font_color", accent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var name_label := Label.new()
	name_label.text = str(card.get("name", "未命名秘术"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override("font_color", Color("f2e5bf"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var route_label := Label.new()
	route_label.text = _route_text(card)
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_label.add_theme_font_size_override("font_size", 13)
	route_label.add_theme_color_override("font_color", Color("9cb4a7"))
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(route_label)

	var divider := ColorRect.new()
	divider.color = Color(accent.r, accent.g, accent.b, 0.38)
	divider.custom_minimum_size = Vector2(0, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	var rank_label := Label.new()
	rank_label.text = _rank_text(card)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 14)
	rank_label.add_theme_color_override("font_color", accent)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rank_label)

	var effect_title := Label.new()
	effect_title.text = "下一级效果"
	effect_title.add_theme_font_size_override("font_size", 13)
	effect_title.add_theme_color_override("font_color", Color("9cb4a7"))
	effect_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(effect_title)

	var effect_label := Label.new()
	effect_label.text = _next_effect_text(card)
	effect_label.add_theme_font_size_override("font_size", 20)
	effect_label.add_theme_color_override("font_color", accent)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(0, 48)
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(effect_label)

	var description := Label.new()
	description.text = _description_text(card)
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", Color("d3dfd6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)

	var strategy := Label.new()
	strategy.text = _strategy_text(card)
	strategy.add_theme_font_size_override("font_size", 13)
	strategy.add_theme_color_override("font_color", Color("e2bb6c"))
	strategy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(strategy)
	return button


func _rank_text(card: Dictionary) -> String:
	var card_id := str(card.get("id", ""))
	var rank := UpgradeManager.get_card_rank(card_id)
	var max_rank := int(card.get("max_rank", 1))
	if max_rank <= 1:
		return "唯一机制  ·  尚未解锁" if rank == 0 else "唯一机制  ·  已解锁"
	return "进阶 %s / %s  ·  %s" % [_to_roman(rank + 1), _to_roman(max_rank), "首次获得" if rank == 0 else "继续精进"]


func _next_effect_text(card: Dictionary) -> String:
	var card_id := str(card.get("id", ""))
	var next_rank := UpgradeManager.get_card_rank(card_id) + 1
	var effect_type := str(card.get("effect_type", ""))
	match effect_type:
		"stat":
			var stat := str(card.get("stat", ""))
			var value := UpgradeManager.get_card_value_for_rank(card_id, next_rank)
			return "+%s  %s" % [_format_value(stat, value), STAT_NAMES.get(stat, stat)]
		"attribute":
			var attribute_id := str(card.get("attribute_id", ""))
			var points := int(UpgradeManager.get_card_value_for_rank(card_id, next_rank))
			return "%s属性熟练度  +%d" % [ATTRIBUTE_NAMES.get(attribute_id, attribute_id), points]
		"modifier":
			return "解锁新的战斗机制"
		_: return "获得一项新的修行增益"


func _format_value(stat: String, value: float) -> String:
	match stat:
		"damage_pct", "move_speed", "attack_speed": return "%d%%" % int(value)
		"hp_regen_5s": return "%.1f / 5秒" % value
		"max_health", "armor", "bullet_count", "attack_range", "pickup_range": return "%d" % int(value)
		_: return "%.1f" % value


func _description_text(card: Dictionary) -> String:
	var card_id := str(card.get("id", ""))
	var next_rank := UpgradeManager.get_card_rank(card_id) + 1
	match str(card.get("effect_type", "")):
		"stat":
			var stat := str(card.get("stat", ""))
			var value := UpgradeManager.get_card_value_for_rank(card_id, next_rank)
			return "提升%s；本次获得 %s。后续阶位收益会继续提高。" % [STAT_NAMES.get(stat, stat), "+%s %s" % [_format_value(stat, value), STAT_NAMES.get(stat, stat)]]
		"attribute":
			var attribute_id := str(card.get("attribute_id", ""))
			var points := int(UpgradeManager.get_card_value_for_rank(card_id, next_rank))
			return "%s属性熟练度 +%d；推进专精等级，并增强相关属性反应。" % [ATTRIBUTE_NAMES.get(attribute_id, attribute_id), points]
		_: return str(card.get("description", "获得一项新的修行增益。"))


func _route_text(card: Dictionary) -> String:
	var required_weapon := str(card.get("requires_weapon", ""))
	if not required_weapon.is_empty():
		return "武器专属 · %s" % WEAPON_NAMES.get(required_weapon, required_weapon)
	match str(card.get("effect_type", "")):
		"stat": return "基础成长 · 可叠加"
		"attribute": return "属性成长 · 推进反应"
		"modifier": return "机制转折 · 改变打法"
		_: return "修行秘术"


func _strategy_text(card: Dictionary) -> String:
	var effect_type := str(card.get("effect_type", ""))
	if effect_type == "stat":
		return "稳定路线  ·  适合补齐短板，最多 %s 阶" % _to_roman(int(card.get("max_rank", 1)))
	if effect_type == "attribute":
		return "构筑路线  ·  提高属性反应触发与专精收益"
	var required_weapon := str(card.get("requires_weapon", ""))
	if not required_weapon.is_empty():
		return "武器转折  ·  让 %s 获得新的攻击节奏" % WEAPON_NAMES.get(required_weapon, required_weapon)
	return "战术转折  ·  这张卡只出现一次，但会改变下一阶段的处理方式"


func _card_accent(card: Dictionary) -> Color:
	var rarity := str(card.get("rarity", "common"))
	var base: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	match str(card.get("effect_type", "")):
		"attribute": return Color(base.r * 0.88, base.g * 0.98, base.b * 1.08, 1.0)
		"modifier": return Color(base.r * 1.05, base.g * 0.94, base.b * 0.86, 1.0)
		_: return base


func _make_card_style(accent: Color, fill_alpha: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.105, 0.13, 0.98)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.94)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24.0
	style.content_margin_top = 20.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 20.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, fill_alpha)
	style.shadow_size = 12
	return style


func _make_badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(6)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	return style


func _on_card_selected(card: Dictionary) -> void:
	if not selecting:
		return
	if not UpgradeManager.acquire_card(str(card.get("id", ""))):
		return
	selecting = false
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not selecting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var choice := -1
		match event.keycode:
			KEY_1, KEY_KP_1: choice = 0
			KEY_2, KEY_KP_2: choice = 1
			KEY_3, KEY_KP_3: choice = 2
		if choice >= 0 and choice < card_container.get_child_count():
			var button := card_container.get_child(choice) as Button
			if button:
				button.emit_signal("pressed")


func _to_roman(value: int) -> String:
	match value:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
		_: return str(value)
