extends Control
class_name BuildStatusHud

## Compact in-run build panel.  This is deliberately a view of the player's
## current run, not a build-management system: it never saves, presets or
## edits a build outside the level-up choice.

const RARITY_COLORS := {
	"common": Color("b7c4d1"),
	"uncommon": Color("62d5b0"),
	"rare": Color("e9b45e")
}

const PANEL_COLOR := Color("0b232b")
const TEXT_COLOR := Color("f1f5f6")
const MUTED_COLOR := Color("9cb4a7")

var build_panel: PanelContainer
var card_title: Label
var build_summary_label: Label
var card_flow: GridContainer
var overflow_label: Label
var runtime_panel: PanelContainer
var runtime_label: Label
var card_signature: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	_refresh_cards(true)
	_refresh_runtime()

func _process(_delta: float) -> void:
	_refresh_cards(false)
	_refresh_runtime()

func _build_controls() -> void:
	build_panel = PanelContainer.new()
	build_panel.name = "RunBuildPanel"
	build_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_panel.position = Vector2(-624, -224)
	build_panel.size = Vector2(600, 200)
	build_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("5e9bb0"), 0.20))
	add_child(build_panel)
	var panel_margin := _make_margin(build_panel, 14)
	var build_box := VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 5)
	panel_margin.add_child(build_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	build_box.add_child(header)
	card_title = Label.new()
	card_title.add_theme_font_size_override("font_size", 17)
	card_title.add_theme_color_override("font_color", Color("e9b45e"))
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(card_title)
	var hint := Label.new()
	hint.text = "本局形成"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	header.add_child(hint)

	build_summary_label = Label.new()
	build_summary_label.add_theme_font_size_override("font_size", 12)
	build_summary_label.add_theme_color_override("font_color", MUTED_COLOR)
	build_summary_label.text = "属性 · 暂无  ·  机制 · 暂无"
	build_summary_label.clip_text = true
	build_box.add_child(build_summary_label)

	card_flow = GridContainer.new()
	card_flow.name = "CardGrid"
	card_flow.columns = 4
	card_flow.add_theme_constant_override("h_separation", 6)
	card_flow.add_theme_constant_override("v_separation", 6)
	card_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_box.add_child(card_flow)

	overflow_label = Label.new()
	overflow_label.add_theme_font_size_override("font_size", 11)
	overflow_label.add_theme_color_override("font_color", MUTED_COLOR)
	overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_box.add_child(overflow_label)

	runtime_panel = PanelContainer.new()
	runtime_panel.name = "CombatStatusPanel"
	runtime_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	runtime_panel.position = Vector2(24, -332)
	runtime_panel.size = Vector2(520, 54)
	runtime_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("6db5d1"), 0.16))
	add_child(runtime_panel)
	var runtime_margin := _make_margin(runtime_panel, 12)
	runtime_label = Label.new()
	runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	runtime_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	runtime_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runtime_label.add_theme_font_size_override("font_size", 13)
	runtime_label.add_theme_color_override("font_color", Color("d7edf2"))
	runtime_margin.add_child(runtime_label)

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
	card_title.text = "本局构筑  ·  %d 张" % cards.size() if not cards.is_empty() else "本局构筑  ·  尚未成形"
	var max_visible := 8
	var start_index := maxi(cards.size() - max_visible, 0)
	for index in range(start_index, cards.size()):
		card_flow.add_child(_make_card_chip(cards[index]))
	var hidden_count := start_index
	overflow_label.text = "最近显示 %d 张  ·  其余 %d 张以当前构筑效果为准" % [cards.size() - hidden_count, hidden_count] if hidden_count > 0 else ""

func _make_card_chip(card: Dictionary) -> PanelContainer:
	var rarity := str(card.get("rarity", "common"))
	var accent: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(138.0, 42.0)
	panel.tooltip_text = "%s\n%s" % [str(card.get("name", "")), str(card.get("description", ""))]
	panel.add_theme_stylebox_override("panel", _make_panel_style(accent, 0.22))
	var label := Label.new()
	label.text = "%s  %s  · %s" % [_category_mark(str(card.get("category", ""))), _short_name(str(card.get("name", ""))), _rank_mark(int(card.get("rank", 1)))]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.clip_text = true
	panel.add_child(label)
	return panel

func _refresh_runtime() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	var status_parts: Array[String] = []
	if player and player.has_method("get_weapon_status_lines"):
		status_parts.append_array(player.get_weapon_status_lines())
	if player and player.has_method("get_special_profile"):
		var special_profile: Dictionary = player.get_special_profile()
		var special_remaining := float(player.get_special_cooldown_remaining())
		status_parts.append("诀技·%s：READY" % str(special_profile.get("name", "秘术")) if special_remaining <= 0.0 else "诀技：%.1fs" % special_remaining)
	if GameManager.has_upgrade("core_revenge"):
		status_parts.append("护核反冲：READY" if GameManager.core_revenge_ready else "护核反冲：待触发")
	if GameManager.has_upgrade("special_core_repair"):
		status_parts.append("借核：READY" if GameManager.special_core_repair_timer <= 0.0 else "借核：%.1fs" % GameManager.special_core_repair_timer)
	if GameManager.has_upgrade("reaction_overload"):
		status_parts.append("反应过载：冷却-20%")
	if GameManager.has_upgrade("chain_echo"):
		status_parts.append("连锁余波：%.0f%%" % (GameManager.get_upgrade_modifier("reaction_spread_chance") * 100.0))
	if GameManager.has_upgrade("special_aftershock"):
		status_parts.append("余震：3目标触发")
	var visible_parts: Array[String] = []
	for index in range(mini(status_parts.size(), 4)):
		visible_parts.append(status_parts[index])
	runtime_label.text = "战斗机制  ·  " + "  ·  ".join(visible_parts) if not visible_parts.is_empty() else "战斗机制  ·  暂无特殊效果"
	var cards: Array[Dictionary] = UpgradeManager.get_acquired_cards()
	var mechanics: Array[String] = []
	for card in cards:
		var category := str(card.get("category", ""))
		if not mechanics.has(category):
			mechanics.append(category)
	var mechanic_text := "、".join(mechanics.slice(0, 3)) if not mechanics.is_empty() else "暂无"
	build_summary_label.text = "属性 · %s  ·  机制 · %s" % [GameManager.get_attribute_summary(), mechanic_text]

func _make_margin(parent: Control, margin: int) -> MarginContainer:
	var container := MarginContainer.new()
	container.add_theme_constant_override("margin_left", margin)
	container.add_theme_constant_override("margin_top", margin)
	container.add_theme_constant_override("margin_right", margin)
	container.add_theme_constant_override("margin_bottom", margin)
	parent.add_child(container)
	return container

func _make_panel_style(accent: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_COLOR.r, PANEL_COLOR.g, PANEL_COLOR.b, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, alpha)
	style.shadow_size = 6
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
