extends Control
class_name BuildStatusHud

const RARITY_COLORS := {
	"common": Color("b7c4d1"),
	"uncommon": Color("62d5b0"),
	"rare": Color("e9b45e")
}

var card_title: Label
var card_flow: FlowContainer
var runtime_panel: PanelContainer
var runtime_label: Label
var card_signature: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	runtime_panel.visible = false
	_refresh_cards(true)
	_refresh_runtime()

func _process(_delta: float) -> void:
	_refresh_cards(false)
	_refresh_runtime()

func _build_controls() -> void:
	card_title = Label.new()
	card_title.anchor_left = 1.0
	card_title.anchor_right = 1.0
	card_title.offset_left = -520.0
	card_title.anchor_top = 1.0
	card_title.anchor_bottom = 1.0
	card_title.offset_top = -120.0
	card_title.offset_right = -20.0
	card_title.offset_bottom = -94.0
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_title.add_theme_font_size_override("font_size", 16)
	card_title.add_theme_color_override("font_color", Color("e9b45e"))
	add_child(card_title)

	card_flow = FlowContainer.new()
	card_flow.anchor_left = 1.0
	card_flow.anchor_right = 1.0
	card_flow.offset_left = -520.0
	card_flow.anchor_top = 1.0
	card_flow.anchor_bottom = 1.0
	card_flow.offset_top = -92.0
	card_flow.offset_right = -20.0
	card_flow.offset_bottom = -18.0
	card_flow.alignment = FlowContainer.ALIGNMENT_END
	card_flow.add_theme_constant_override("h_separation", 6)
	card_flow.add_theme_constant_override("v_separation", 6)
	add_child(card_flow)

	runtime_panel = PanelContainer.new()
	runtime_panel.anchor_top = 1.0
	runtime_panel.anchor_bottom = 1.0
	runtime_panel.offset_left = 20.0
	runtime_panel.offset_top = -294.0
	runtime_panel.offset_right = 760.0
	runtime_panel.offset_bottom = -246.0
	runtime_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("6db5d1"), 0.18))
	add_child(runtime_panel)

	runtime_label = Label.new()
	runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	runtime_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runtime_label.add_theme_font_size_override("font_size", 16)
	runtime_label.add_theme_color_override("font_color", Color("d7edf2"))
	runtime_panel.add_child(runtime_label)

func _refresh_cards(force: bool) -> void:
	var cards: Array[Dictionary] = UpgradeManager.get_acquired_cards()
	var signature_parts: Array[String] = []
	for card in cards:
		signature_parts.append("%s:%d" % [str(card.get("id", "")), int(card.get("rank", 1))])
	var new_signature := ";".join(signature_parts)
	if not force and new_signature == card_signature:
		return
	card_signature = new_signature
	for child in card_flow.get_children():
		child.queue_free()
	card_title.text = "构筑 · %d 张" % cards.size() if not cards.is_empty() else "构筑 · 暂无卡片"
	for card in cards:
		card_flow.add_child(_make_card_chip(card))

func _make_card_chip(card: Dictionary) -> PanelContainer:
	var rarity := str(card.get("rarity", "common"))
	var accent: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(78.0, 38.0)
	panel.tooltip_text = "%s\n%s" % [str(card.get("name", "")), str(card.get("description", ""))]
	panel.add_theme_stylebox_override("panel", _make_panel_style(accent, 0.22))

	var label := Label.new()
	label.text = "%s %s\n%s" % [_category_mark(str(card.get("category", ""))), _short_name(str(card.get("name", ""))), _rank_mark(int(card.get("rank", 1)))]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("f1f5f6"))
	panel.add_child(label)
	return panel

func _refresh_runtime() -> void:
	var status_parts: Array[String] = []
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_weapon_status_lines"):
		status_parts.append_array(player.get_weapon_status_lines())
	if player and player.has_method("get_special_profile"):
		var special_profile: Dictionary = player.get_special_profile()
		var special_remaining := float(player.get_special_cooldown_remaining())
		if special_remaining <= 0.0:
			status_parts.append("诀技·%s：READY" % str(special_profile.get("name", "秘术")))
		else:
			status_parts.append("诀技：%.1fs" % special_remaining)
	if GameManager.has_upgrade("core_revenge"):
		status_parts.append("护核反冲：READY" if GameManager.core_revenge_ready else "护核反冲：待触发")
	if GameManager.has_upgrade("special_core_repair"):
		if GameManager.special_core_repair_timer > 0.0:
			status_parts.append("借核：%.1fs" % GameManager.special_core_repair_timer)
		else:
			status_parts.append("借核：READY")
	if GameManager.has_upgrade("reaction_overload"):
		status_parts.append("反应过载：冷却-20%")
	if GameManager.has_upgrade("chain_echo"):
		status_parts.append("连锁余波：%.0f%%" % (GameManager.get_upgrade_modifier("reaction_spread_chance") * 100.0))
	if GameManager.has_upgrade("special_aftershock"):
		status_parts.append("余震：3目标触发")
	runtime_label.text = "战斗状态  ·  " + "  ·  ".join(status_parts) if not status_parts.is_empty() else "战斗状态  ·  暂无特殊状态"

func _make_panel_style(accent: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, alpha)
	style.shadow_size = 4
	return style

func _category_mark(category: String) -> String:
	if category.contains("灵剑"): return "剑"
	if category.contains("钢刃"): return "刃"
	if category.contains("长枪"): return "枪"
	if category.contains("符铳"): return "铳"
	if category.contains("属性"): return "属"
	if category.contains("主动"): return "诀"
	if category.contains("灵核"): return "核"
	if category.contains("昼夜"): return "昼"
	return "数"

func _short_name(card_name: String) -> String:
	return card_name.left(5) if card_name.length() > 5 else card_name

func _rank_mark(rank: int) -> String:
	match rank:
		1: return "I"
		2: return "II"
		3: return "III"
		_: return str(rank)
