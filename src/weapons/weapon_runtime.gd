extends RefCounted
class_name WeaponRuntime

## The single runtime contract for the four starting weapons.
##
## Player owns the attack execution (because it owns movement, hitboxes and
## the projectile scene), while this object owns every weapon-specific value
## and readable description.  Keeping the contract data-driven prevents the
## menu, HUD and combat code from growing separate weapon switch statements.

const WEAPON_ORDER := ["sword", "blade", "spear", "musket"]

const WEAPON_DEFINITIONS := {
	"sword": {
		"name": "引霜灵剑",
		"subtitle": "平衡近战",
		"description": "攻守均衡，挥斩稳定，适合第一次踏入秘境。",
		"kind": "melee",
		"attribute": "fire",
		"damage": 10.0,
		"slash_time": 0.2,
		"return_time": 0.5,
		"range_multiplier": 1.0,
		"visual_scale": Vector2(1, 1),
		"texture": "res://assets/textures/weapons/weapon_sword.png",
		"special": {
			"name": "赤焰回环",
			"description": "引爆身边火印，灼烧并击退一圈妖物。",
			"damage": 38.0,
			"radius": 200.0,
			"cooldown": 8.0,
			"color": Color("ee8556"),
			"payload": {"fire": 3, "blast": 2},
			"knockback": 95.0
		}
	},
	"blade": {
		"name": "破鳞钢刃",
		"subtitle": "快速连斩",
		"description": "出手更快，贴身压制妖兽，但攻击距离较短。",
		"kind": "melee",
		"attribute": "poison",
		"damage": 15.0,
		"slash_time": 0.17,
		"return_time": 0.42,
		"range_multiplier": 0.9,
		"visual_scale": Vector2(1, 1),
		"texture": "res://assets/textures/weapons/weapon_blade.png",
		"special": {
			"name": "腐心散",
			"description": "近身毒爆，命中后回复少量生命。",
			"damage": 24.0,
			"radius": 230.0,
			"cooldown": 8.5,
			"color": Color("65c579"),
			"payload": {"poison": 3, "vine": 1},
			"knockback": 55.0,
			"heal_per_hit": 4.0
		}
	},
	"spear": {
		"name": "龙脊长枪",
		"subtitle": "长距爆发",
		"description": "攻击距离与伤害更高，回身较慢，需要预判走位。",
		"kind": "melee",
		"attribute": "ice",
		"damage": 22.0,
		"slash_time": 0.24,
		"return_time": 0.55,
		"range_multiplier": 1.25,
		"visual_scale": Vector2(1, 1),
		"texture": "res://assets/textures/weapons/weapon_spear.png",
		"special": {
			"name": "霜锋震",
			"description": "大范围冰震，冻结并击退周围妖物。",
			"damage": 46.0,
			"radius": 250.0,
			"cooldown": 10.0,
			"color": Color("76c8e8"),
			"payload": {"water": 2, "ice": 3},
			"knockback": 120.0
		}
	},
	"musket": {
		"name": "火符连铳",
		"subtitle": "远程守线",
		"description": "远距离发射符弹，适合守住灵核外围。",
		"kind": "ranged",
		"attribute": "thunder",
		"damage": 16.0,
		"ranged_range": 760.0,
		"ranged_cooldown": 0.8,
		"visual_scale": Vector2(1, 1),
		"texture": "res://assets/textures/weapons/sword_48.png",
		"special": {
			"name": "天雷引",
			"description": "锁定远处五名目标，雷链在敌群间跳跃。",
			"damage": 34.0,
			"radius": 900.0,
			"cooldown": 9.0,
			"color": Color("e4d15e"),
			"payload": {"water": 2, "thunder": 3},
			"max_targets": 5,
			"chain": true
		}
	}
}

var weapon_id: String = "sword"

func _init(selected_id: String = "sword") -> void:
	configure(selected_id)

func configure(selected_id: String) -> void:
	weapon_id = selected_id if WEAPON_DEFINITIONS.has(selected_id) else "sword"

func get_definition() -> Dictionary:
	return WEAPON_DEFINITIONS.get(weapon_id, WEAPON_DEFINITIONS["sword"]).duplicate(true)

func get_special_profile() -> Dictionary:
	var definition := get_definition()
	return Dictionary(definition.get("special", {})).duplicate(true)

func get_attribute_id() -> String:
	return str(get_definition().get("attribute", "fire"))

func is_ranged() -> bool:
	return str(get_definition().get("kind", "melee")) == "ranged"

func get_base_damage() -> float:
	return float(get_definition().get("damage", 10.0))

func get_slash_time() -> float:
	return float(get_definition().get("slash_time", 0.2))

func get_return_time() -> float:
	return float(get_definition().get("return_time", 0.5))

func get_range_multiplier() -> float:
	return float(get_definition().get("range_multiplier", 1.0))

func get_ranged_range() -> float:
	return float(get_definition().get("ranged_range", 760.0))

func get_ranged_cooldown() -> float:
	return float(get_definition().get("ranged_cooldown", 0.8))

func get_visual_scale() -> Vector2:
	return Vector2(get_definition().get("visual_scale", Vector2.ONE))

func get_visual_texture() -> Texture2D:
	var path := str(get_definition().get("texture", ""))
	return load(path) as Texture2D if not path.is_empty() else null

func get_status_lines(player: Node) -> Array[String]:
	var lines: Array[String] = []
	match weapon_id:
		"sword":
			if GameManager.has_upgrade("sword_sweep"):
				var interval := maxi(int(GameManager.get_upgrade_modifier("sword_sweep_interval", 3.0)), 1)
				if bool(player.get("current_slash_is_sweep")):
					lines.append("回风斩：横扫!")
				else:
					lines.append("回风斩：%d/%d" % [int(player.get("slash_count")) % interval, interval])
			if GameManager.has_upgrade("sword_burn_trail"):
				lines.append("焚痕：命中留火")
		"blade":
			if GameManager.has_upgrade("blade_combo"):
				var max_stacks := maxi(int(GameManager.get_upgrade_modifier("blade_combo_max_stacks", 5.0)), 1)
				var combo_count := int(player.get("blade_combo_count"))
				var combo_timer := float(player.get("blade_combo_timer"))
				if combo_count > 0 and combo_timer > 0.0:
					lines.append("连刃：%d/%d" % [combo_count, max_stacks])
				else:
					lines.append("连刃：待命")
			if GameManager.has_upgrade("blade_poison_cloud"):
				lines.append("毒爆：死亡留雾")
		"spear":
			if GameManager.has_upgrade("spear_pierce"):
				if bool(player.get("current_attack_charged")):
					lines.append("贯阵：READY")
				else:
					var charge_ratio := clampf(float(player.get("movement_since_attack")) / 180.0, 0.0, 1.0)
					lines.append("贯阵：%d%%" % int(charge_ratio * 100.0))
			if GameManager.has_upgrade("spear_shatter"):
				lines.append("碎冰：冻结追加")
		"musket":
			if GameManager.has_upgrade("musket_charge"):
				var interval := maxi(int(GameManager.get_upgrade_modifier("musket_charge_interval", 5.0)), 1)
				lines.append("雷符：%d/%d" % [int(player.get("ranged_shot_count")) % interval, interval])
			if GameManager.has_upgrade("musket_aura"):
				lines.append("守线：生效" if GameManager.player_in_aura else "守线：待入阵")
	return lines

static func get_all_definitions() -> Dictionary:
	return WEAPON_DEFINITIONS.duplicate(true)
