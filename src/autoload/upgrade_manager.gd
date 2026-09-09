extends Node

## Roguelike upgrade catalog and the run-local card collection.
## Stat cards are repeatable up to three ranks; behavior cards are intentionally
## unique so a run gains distinct identities instead of only larger numbers.

const CARD_CATALOG: Array[Dictionary] = [
	# 基础成长
	{"id": "stat_max_health", "name": "淬体", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "max_health", "value": 20.0, "description": "最大生命 +20。"},
	{"id": "stat_damage", "name": "锋芒", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "damage_pct", "value": 10.0, "description": "造成伤害 +10%。"},
	{"id": "stat_speed", "name": "踏风", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "move_speed", "value": 5.0, "description": "移动速度 +5%。"},
	{"id": "stat_armor", "name": "铁骨", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "armor", "value": 2.0, "description": "护甲 +2。"},
	{"id": "stat_attack_speed", "name": "急运", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "attack_speed", "value": 10.0, "description": "攻击速度 +10%。"},
	{"id": "stat_bullet_count", "name": "多符", "category": "基础强化", "rarity": "uncommon", "max_rank": 2, "effect_type": "stat", "stat": "bullet_count", "value": 1.0, "description": "远程攻击额外发射 1 枚弹体。"},
	{"id": "stat_regen", "name": "回元", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "hp_regen_5s", "value": 1.0, "description": "每 5 秒回复生命 +1。"},
	{"id": "stat_attack_range", "name": "延锋", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "attack_range", "value": 100.0, "description": "攻击范围 +100。"},
	{"id": "stat_pickup_range", "name": "摄灵", "category": "基础强化", "rarity": "common", "max_rank": 3, "effect_type": "stat", "stat": "pickup_range", "value": 100.0, "description": "灵性球拾取范围 +100。"},

	# 属性熟练度
	{"id": "attribute_fire", "name": "火·焚锋", "category": "属性构筑", "rarity": "common", "max_rank": 3, "effect_type": "attribute", "attribute_id": "fire", "value": 3, "description": "火属性熟练度 +3。灼烧目标并持续造成伤害。"},
	{"id": "attribute_blast", "name": "爆·爆燃", "category": "属性构筑", "rarity": "uncommon", "max_rank": 3, "effect_type": "attribute", "attribute_id": "blast", "value": 3, "description": "爆属性熟练度 +3。积累爆印，等待反应引爆。"},
	{"id": "attribute_poison", "name": "毒·毒蚀", "category": "属性构筑", "rarity": "common", "max_rank": 3, "effect_type": "attribute", "attribute_id": "poison", "value": 3, "description": "毒属性熟练度 +3。持续腐蚀并压制治疗。"},
	{"id": "attribute_vine", "name": "藤·荆棘", "category": "属性构筑", "rarity": "uncommon", "max_rank": 3, "effect_type": "attribute", "attribute_id": "vine", "value": 3, "description": "藤属性熟练度 +3。减速并束缚目标。"},
	{"id": "attribute_water", "name": "水·浸润", "category": "属性构筑", "rarity": "common", "max_rank": 3, "effect_type": "attribute", "attribute_id": "water", "value": 3, "description": "水属性熟练度 +3。强化后续属性反应。"},
	{"id": "attribute_ice", "name": "冰·凝霜", "category": "属性构筑", "rarity": "uncommon", "max_rank": 3, "effect_type": "attribute", "attribute_id": "ice", "value": 3, "description": "冰属性熟练度 +3。减速、冻结并制造碎裂机会。"},
	{"id": "attribute_wind", "name": "风·风刃", "category": "属性构筑", "rarity": "common", "max_rank": 3, "effect_type": "attribute", "attribute_id": "wind", "value": 3, "description": "风属性熟练度 +3。留下风痕并扩散状态。"},
	{"id": "attribute_thunder", "name": "雷·引雷", "category": "属性构筑", "rarity": "uncommon", "max_rank": 3, "effect_type": "attribute", "attribute_id": "thunder", "value": 3, "description": "雷属性熟练度 +3。触发链式闪电与麻痹。"},

	# 通用玩法卡
	{"id": "reaction_overload", "name": "反应过载", "category": "属性反应", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"reaction_cooldown_reduction": 0.20}, "description": "属性反应冷却缩短 20%。"},
	{"id": "chain_echo", "name": "连锁余波", "category": "属性反应", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"reaction_spread_chance": 0.25, "reaction_spread_count": 1.0}, "description": "触发反应时有 25% 概率向附近 1 名敌人扩散触发属性。"},
	{"id": "special_aftershock", "name": "诀技·余震", "category": "主动诀技", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"special_aftershock_damage_pct": 0.25, "special_aftershock_radius": 140.0}, "description": "主动诀技命中 3 名以上敌人后，留下 2.5 秒余震区。"},
	{"id": "special_core_repair", "name": "诀技·借核", "category": "主动诀技", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"special_core_repair_amount": 5.0, "special_core_repair_interval": 12.0}, "description": "在光环内释放主动诀技时，灵核恢复 5 点耐久，每 12 秒一次。"},
	{"id": "special_radius", "name": "诀技·扩域", "category": "主动诀技", "rarity": "common", "max_rank": 1, "effect_type": "modifier", "modifiers": {"special_radius_bonus": 60.0}, "description": "主动诀技范围 +60。"},
	{"id": "core_revenge", "name": "护核反冲", "category": "灵核战术", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"core_revenge_damage_pct": 0.35}, "description": "灵核受击后，下一次主动诀技伤害 +35%。"},
	{"id": "core_guardian", "name": "守核誓", "category": "灵核战术", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"core_damage_reduction_pct": 0.15}, "description": "灵核受到的伤害降低 15%。"},
	{"id": "aura_slow", "name": "归阵·缚灵", "category": "灵核战术", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"core_aura_slow_pct": 0.25}, "description": "灵核光环内的敌人移动速度降低 25%。"},
	{"id": "far_hunt", "name": "远征令", "category": "昼夜取舍", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"outside_aura_damage_pct": 20.0, "core_damage_taken_pct": 0.10}, "description": "离开光环时伤害 +20%，但灵核受到的伤害 +10%。"},
	{"id": "spirit_harvest", "name": "余灵回收", "category": "昼夜取舍", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"day_bonus_orb_chance": 0.20}, "description": "白天击杀敌人时，有额外 20% 概率掉落灵性球；夜间不生效。"},
	{"id": "attribute_shift", "name": "五相轮转", "category": "属性切换", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"attribute_shift_interval": 4.5, "attribute_shift_damage_pct": 0.15}, "description": "拥有两种以上属性时，每 4.5 秒切换一次主属性；当前属性攻击伤害 +15%。"},
	{"id": "attribute_prism", "name": "棱镜余辉", "category": "属性切换", "rarity": "rare", "max_rank": 1, "requires_card": "attribute_shift", "effect_type": "modifier", "modifiers": {"attribute_shift_echo_level": 1.0}, "description": "五相轮转时保留下一属性的微弱余辉，主属性仍可与余辉触发反应。"},
	{"id": "critical_edge", "name": "破命锋", "category": "暴击构筑", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"critical_chance": 0.12, "critical_multiplier": 0.75}, "description": "所有攻击有 12% 概率暴击，暴击伤害为普通伤害的 2.25 倍。"},
	{"id": "critical_explosion", "name": "星火裂命", "category": "暴击构筑", "rarity": "rare", "max_rank": 1, "requires_card": "critical_edge", "effect_type": "modifier", "modifiers": {"critical_explosion_radius": 115.0, "critical_explosion_damage_pct": 0.55}, "description": "暴击会在目标处引发星火爆炸，对附近妖物造成暴击伤害的 55%。"},
	{"id": "reaction_overflow", "name": "反应溢流", "category": "属性反应", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"reaction_damage_pct": 0.30}, "description": "属性反应伤害 +30%；反应伤害越高，越容易把小范围战斗变成连锁清场。"},
	{"id": "status_detonator", "name": "蚀印爆破", "category": "属性反应", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"status_detonator_stacks": 3.0, "status_detonator_damage_pct": 0.32, "status_detonator_radius": 75.0}, "description": "同一属性叠到 3 层时引爆蚀印，造成一次基于本次攻击的范围伤害并清空该属性层数。"},
	{"id": "momentum_edge", "name": "踏阵蓄势", "category": "机动构筑", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"momentum_distance": 220.0, "momentum_damage_pct": 0.28}, "description": "移动累计 220 距离后，下一次攻击获得 +28% 伤害；命中后重新蓄势。"},
	{"id": "orb_alchemy", "name": "灵珠炼体", "category": "灵性经济", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"orb_alchemy_heal": 2.0}, "description": "拾取任意灵性球时恢复 2 点生命；越敢离开光环，越能把资源转成续航。"},
	{"id": "rainbow_confluence", "name": "四色归一", "category": "四色共鸣", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"rainbow_damage_pct": 18.0, "rainbow_threshold": 1.0}, "description": "四种颜色都至少拥有 1 颗灵性球时，获得 +18% 全局伤害；颜色越齐，构筑越稳定。"},
	{"id": "aura_forge", "name": "阵内铸身", "category": "灵核战术", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"aura_armor": 5.0, "aura_damage_pct": 12.0}, "description": "站在灵核光环内时护甲 +5、伤害 +12%；把回防变成主动蓄力窗口。"},
	{"id": "low_health_frenzy", "name": "残照反击", "category": "生存构筑", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"low_health_threshold": 0.35, "low_health_damage_pct": 35.0}, "description": "生命低于 35% 时伤害 +35%；危险状态下反而拥有翻盘窗口。"},
	{"id": "boss_hunter", "name": "斩妖契", "category": "终局构筑", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"boss_damage_pct": 30.0}, "description": "对大妖伤害 +30%；提前挑战山门会更有收益，但不能替代走位。"},
	{"id": "execution_burst", "name": "断魂余爆", "category": "终结构筑", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"execution_burst_radius": 85.0, "execution_burst_damage": 20.0}, "description": "击杀妖物时留下断魂余爆，对附近敌人造成范围伤害；适合滚雪球清群。"},
	{"id": "overkill_conversion", "name": "溢伤转余劲", "category": "余劲收割", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"overkill_damage_pct": 0.65, "overkill_radius": 185.0, "overkill_chain_depth": 2.0}, "description": "击杀妖物时，溢出的伤害会化为余劲，自动追向附近目标。单体重击也能撕开敌群。"},
	{"id": "overkill_split", "name": "余劲分裂", "category": "余劲收割", "rarity": "uncommon", "max_rank": 1, "requires_card": "overkill_conversion", "effect_type": "modifier", "modifiers": {"overkill_chain_count": 2.0, "overkill_split_damage_pct": 0.45}, "description": "余劲会同时寻找两个目标；后续目标仍会保留一部分余伤，适合暴击和高倍率武器。"},
	{"id": "aegis_resonance", "name": "受命·护轮", "category": "破盾反击", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"shield_on_orb": 6.0, "shield_max": 36.0, "shield_revenge_pct": 0.65, "shield_break_radius": 105.0}, "description": "拾取灵性球获得临时护盾；护盾吸收的伤害会储存为反震力，护盾破碎时释放。"},
	{"id": "shield_breaker", "name": "破势", "category": "破盾反击", "rarity": "uncommon", "max_rank": 1, "requires_card": "aegis_resonance", "effect_type": "modifier", "modifiers": {"shield_break_damage_pct": 0.80, "shield_break_radius": 35.0}, "description": "护盾破碎时，反震力变成范围冲击波；承受攻击的时机也能变成清场窗口。"},
	{"id": "shield_revenge", "name": "借劫还锋", "category": "破盾反击", "rarity": "rare", "max_rank": 1, "requires_card": "shield_breaker", "effect_type": "modifier", "modifiers": {"shield_refund_per_kill": 5.0, "shield_break_damage_pct": 0.35}, "description": "反震击杀敌人时返还护盾；返还的护盾越多，下一次破盾爆发越快。"},
	{"id": "afterimage", "name": "踏影", "category": "残影复刻", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"afterimage_distance": 260.0, "afterimage_radius": 72.0, "afterimage_damage_pct": 0.25}, "description": "移动达到距离后留下残影；下一次攻击会在残影处留下 25% 伤害的回响。"},
	{"id": "afterimage_echo", "name": "复刻", "category": "残影复刻", "rarity": "rare", "max_rank": 1, "requires_card": "afterimage", "effect_type": "modifier", "modifiers": {"afterimage_damage_pct": 0.65}, "description": "残影会复刻下一次攻击，对附近妖物造成 65% 伤害；攻击方式越重，回响越危险。"},
	{"id": "afterimage_return", "name": "归影", "category": "残影复刻", "rarity": "uncommon", "max_rank": 1, "requires_card": "afterimage_echo", "effect_type": "modifier", "modifiers": {"afterimage_cooldown_refund": 0.45}, "description": "残影命中后返还秘术冷却；移动、攻击、再移动可以形成连续循环。"},
	{"id": "fracture_mark", "name": "开脉", "category": "裂痕收割", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"fracture_threshold": 5.0, "fracture_duration": 2.2}, "description": "攻击同一目标会积累裂痕；裂痕达到上限后，目标进入可被收割的破绽状态。"},
	{"id": "fracture_harvest", "name": "断脉收割", "category": "裂痕收割", "rarity": "rare", "max_rank": 1, "requires_card": "fracture_mark", "effect_type": "modifier", "modifiers": {"fracture_damage_pct": 0.70, "fracture_radius": 90.0, "fracture_spread": 1.0}, "description": "收割裂痕会造成额外伤害，并把裂痕传给附近敌人；轻击铺垫，重击收尾。"},
	{"id": "attribute_overload", "name": "单相过载", "category": "属性过载", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"attribute_overload_threshold": 6.0, "attribute_overload_damage_pct": 1.20, "attribute_overload_radius": 90.0}, "description": "只使用一种属性时会积累过载；达到阈值后，下一次命中引发该属性爆发。"},
	{"id": "attribute_overload_echo", "name": "余温回响", "category": "属性过载", "rarity": "uncommon", "max_rank": 1, "requires_card": "attribute_overload", "effect_type": "modifier", "modifiers": {"attribute_overload_damage_pct": 0.35, "attribute_overload_radius": 25.0}, "description": "过载爆发后留下短暂余温，范围内的敌人会继续承受当前属性的压力。"},
	{"id": "returning_edge", "name": "回锋", "category": "弹道回收", "rarity": "rare", "max_rank": 1, "effect_type": "modifier", "modifiers": {"return_projectile_damage_pct": 0.65, "return_projectile_speed": 820.0, "return_projectile_pierce_count": 1.0}, "description": "远程弹道命中敌人后返回自身；去程和回程是两次不同的攻击机会。"},
	{"id": "return_double", "name": "双相回锋", "category": "弹道回收", "rarity": "uncommon", "max_rank": 1, "requires_card": "returning_edge", "effect_type": "modifier", "modifiers": {"return_projectile_damage_bonus_pct": 0.35, "return_projectile_pierce_count": 1.0}, "description": "回程伤害提高，并可穿过更多敌人；让弹道真正成为一条来回的攻击线。"},
	{"id": "kill_rhythm", "name": "收割节奏", "category": "击杀返还", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"kill_cooldown_refund": 0.45, "kill_attack_refund": 0.18, "kill_streak_window": 2.0}, "description": "击杀妖物会返还攻击与秘术冷却；连续击杀能把战斗节奏越滚越快。"},
	{"id": "kill_chain", "name": "追魂三响", "category": "击杀返还", "rarity": "rare", "max_rank": 1, "requires_card": "kill_rhythm", "effect_type": "modifier", "modifiers": {"kill_streak_threshold": 3.0, "kill_streak_special_refund": 1.5}, "description": "短时间内连续击杀三名敌人，会额外返还秘术冷却；适合主动追杀而非慢慢消耗。"},
	{"id": "damage_alchemy", "name": "淬锋", "category": "伤害转化", "rarity": "uncommon", "max_rank": 1, "effect_type": "modifier", "modifiers": {"transmute_charge_pct": 0.20, "transmute_max_charge": 90.0}, "description": "属性反应伤害会转化为淬锋值，储存在下一次攻击里；反应不是终点，而是下一击的燃料。"},
	{"id": "damage_transmute", "name": "反炼", "category": "伤害转化", "rarity": "rare", "max_rank": 1, "requires_card": "damage_alchemy", "effect_type": "modifier", "modifiers": {"transmute_burst_pct": 0.75, "transmute_radius": 82.0}, "description": "消耗淬锋值攻击时，会在命中点额外爆发；属性反应、蓄力和暴击可以互相喂养。"},

	# 灵剑
	{"id": "sword_sweep", "name": "回风斩", "category": "灵剑形态", "rarity": "rare", "max_rank": 1, "requires_weapon": "sword", "effect_type": "modifier", "modifiers": {"sword_sweep_interval": 3.0, "sword_sweep_damage_pct": 0.75}, "description": "每第 3 次挥斩变为 360° 横扫，伤害为普通挥斩的 75%。"},
	{"id": "sword_burn_trail", "name": "焚痕", "category": "灵剑形态", "rarity": "uncommon", "max_rank": 1, "requires_weapon": "sword", "effect_type": "modifier", "modifiers": {"sword_burn_trail_damage": 12.0, "sword_burn_trail_duration": 2.0, "sword_burn_trail_radius": 70.0}, "description": "挥斩命中后在目标脚下留下 2 秒火痕。"},

	# 钢刃
	{"id": "blade_combo", "name": "连刃", "category": "钢刃形态", "rarity": "rare", "max_rank": 1, "requires_weapon": "blade", "effect_type": "modifier", "modifiers": {"blade_combo_window": 1.2, "blade_combo_damage_pct": 0.06, "blade_combo_max_stacks": 5.0}, "description": "1.2 秒内连续命中同一目标会叠加连击，最多 5 层，每层伤害 +6%。"},
	{"id": "blade_poison_cloud", "name": "毒爆", "category": "钢刃形态", "rarity": "uncommon", "max_rank": 1, "requires_weapon": "blade", "effect_type": "modifier", "modifiers": {"blade_poison_cloud_damage": 4.0, "blade_poison_cloud_duration": 3.0, "blade_poison_cloud_radius": 90.0}, "description": "中毒敌人死亡时留下 3 秒毒雾。"},

	# 长枪
	{"id": "spear_pierce", "name": "贯阵", "category": "长枪形态", "rarity": "rare", "max_rank": 1, "requires_weapon": "spear", "effect_type": "modifier", "modifiers": {"spear_pierce_count": 2.0, "spear_pierce_damage_pct": 0.65}, "description": "连续移动 180 后，下一次长枪普攻向攻击方向穿透 2 名敌人，后续目标伤害为 65%。"},
	{"id": "spear_shatter", "name": "碎冰", "category": "长枪形态", "rarity": "uncommon", "max_rank": 1, "requires_weapon": "spear", "effect_type": "modifier", "modifiers": {"spear_shatter_damage_pct": 0.80}, "description": "攻击冻结目标时追加一次 80% 伤害的碎冰打击。"},

	# 符铳
	{"id": "musket_charge", "name": "定装雷符", "category": "符铳形态", "rarity": "rare", "max_rank": 1, "requires_weapon": "musket", "effect_type": "modifier", "modifiers": {"musket_charge_interval": 5.0, "musket_charge_damage_pct": 0.35, "musket_charge_pierce_count": 3.0}, "description": "每第 5 次射击发射一枚强化穿透雷弹。"},
	{"id": "musket_aura", "name": "守线", "category": "符铳形态", "rarity": "uncommon", "max_rank": 1, "requires_weapon": "musket", "effect_type": "modifier", "modifiers": {"musket_aura_damage_pct": 0.25}, "description": "灵核光环内射击伤害 +25%。"}
]

const RARITY_WEIGHTS := {"common": 6.0, "uncommon": 3.0, "rare": 1.0}

# 每一阶的真实收益。UI 会展示“当前 -> 下一阶”，领取时也使用同一张表，
# 避免卡面数字和战斗实际数值脱节。
const CARD_RANK_VALUES := {
	"stat_max_health": [20.0, 24.0, 28.0],
	"stat_damage": [10.0, 12.0, 15.0],
	"stat_speed": [5.0, 6.0, 8.0],
	"stat_armor": [2.0, 3.0, 4.0],
	"stat_attack_speed": [10.0, 12.0, 15.0],
	"stat_bullet_count": [1.0, 1.0],
	"stat_regen": [1.0, 2.0, 3.0],
	"stat_attack_range": [100.0, 120.0, 150.0],
	"stat_pickup_range": [100.0, 120.0, 150.0],
	"attribute_fire": [3.0, 4.0, 5.0],
	"attribute_blast": [3.0, 4.0, 5.0],
	"attribute_poison": [3.0, 4.0, 5.0],
	"attribute_vine": [3.0, 4.0, 5.0],
	"attribute_water": [3.0, 4.0, 5.0],
	"attribute_ice": [3.0, 4.0, 5.0],
	"attribute_wind": [3.0, 4.0, 5.0],
	"attribute_thunder": [3.0, 4.0, 5.0]
}

var acquired_cards: Dictionary = {}
var current_offer: Array[Dictionary] = []

func reset_run() -> void:
	acquired_cards.clear()
	current_offer.clear()

func get_card_definition(card_id: String) -> Dictionary:
	for card in CARD_CATALOG:
		if str(card.get("id", "")) == card_id:
			return card.duplicate(true)
	return {}

func get_card_rank(card_id: String) -> int:
	return int(acquired_cards.get(card_id, 0))

func get_card_value_for_rank(card_id: String, rank: int) -> float:
	var card := get_card_definition(card_id)
	if card.is_empty() or rank <= 0:
		return 0.0
	var values: Array = CARD_RANK_VALUES.get(card_id, [])
	if values.is_empty():
		return float(card.get("value", 0.0))
	var index := clampi(rank - 1, 0, values.size() - 1)
	return float(values[index])

func has_card(card_id: String) -> bool:
	return get_card_rank(card_id) > 0

func get_modifier(modifier_id: String, default_value: float = 0.0) -> float:
	var value := default_value
	for card_id in acquired_cards:
		var card := get_card_definition(str(card_id))
		var modifiers: Dictionary = card.get("modifiers", {})
		value += float(modifiers.get(modifier_id, 0.0)) * int(acquired_cards[card_id])
	return value

func get_acquired_card_summary() -> String:
	var parts: Array[String] = []
	for card in CARD_CATALOG:
		var card_id := str(card.get("id", ""))
		var rank := get_card_rank(card_id)
		if rank <= 0:
			continue
		parts.append("%s %s" % [str(card.get("name", card_id)), _rank_mark(rank)])
	return "、".join(parts) if not parts.is_empty() else "暂无"

func get_acquired_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for card in CARD_CATALOG:
		var card_id := str(card.get("id", ""))
		var rank := get_card_rank(card_id)
		if rank <= 0:
			continue
		var acquired_card := card.duplicate(true)
		acquired_card["rank"] = rank
		cards.append(acquired_card)
	return cards

func _rank_mark(rank: int) -> String:
	match rank:
		1: return "I"
		2: return "II"
		3: return "III"
		_: return str(rank)

func get_offer(count: int = 3) -> Array[Dictionary]:
	var available := _get_available_cards()
	var offer: Array[Dictionary] = []
	if available.is_empty():
		current_offer = offer
		return offer

	# 第一张优先给玩法卡，保证升级不再连续出现三张纯数值卡。
	var behavior_pool: Array[Dictionary] = []
	for card in available:
		if str(card.get("effect_type", "")) == "modifier":
			behavior_pool.append(card)
	if not behavior_pool.is_empty():
		offer.append(_pick_weighted(behavior_pool, []))

	while offer.size() < count and offer.size() < available.size():
		var diverse_pool: Array[Dictionary] = []
		var used_categories: Dictionary = {}
		for selected in offer:
			used_categories[str(selected.get("category", ""))] = true
		for candidate in available:
			if not used_categories.has(str(candidate.get("category", ""))):
				diverse_pool.append(candidate)
		var pool := diverse_pool if not diverse_pool.is_empty() else available
		var picked := _pick_weighted(pool, offer)
		if picked.is_empty():
			break
		offer.append(picked)

	current_offer = offer
	return offer

func acquire_card(card_id: String) -> bool:
	var card := get_card_definition(card_id)
	if card.is_empty():
		return false
	var required_weapon := str(card.get("requires_weapon", ""))
	if not required_weapon.is_empty() and required_weapon != GameManager.selected_weapon_id:
		return false
	var required_card := str(card.get("requires_card", ""))
	if not required_card.is_empty() and not has_card(required_card):
		return false
	var current_rank := get_card_rank(card_id)
	var max_rank := int(card.get("max_rank", 1))
	if current_rank >= max_rank:
		return false

	var new_rank := current_rank + 1
	acquired_cards[card_id] = new_rank
	match str(card.get("effect_type", "")):
		"stat":
			GameManager.apply_card_upgrade(str(card.get("stat", "")), get_card_value_for_rank(card_id, new_rank))
		"attribute":
			GameManager.apply_attribute_upgrade(str(card.get("attribute_id", "")), int(get_card_value_for_rank(card_id, new_rank)))
		"modifier":
			GameManager.update_current_stats()
	EventBus.card_acquired.emit(card_id, new_rank)
	return true

func _get_available_cards() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for card in CARD_CATALOG:
		var card_id := str(card.get("id", ""))
		if card_id.is_empty() or get_card_rank(card_id) >= int(card.get("max_rank", 1)):
			continue
		var required_weapon := str(card.get("requires_weapon", ""))
		if not required_weapon.is_empty() and required_weapon != GameManager.selected_weapon_id:
			continue
		var required_card := str(card.get("requires_card", ""))
		if not required_card.is_empty() and not has_card(required_card):
			continue
		available.append(card.duplicate(true))
	return available

func _pick_weighted(pool: Array[Dictionary], excluded: Array[Dictionary]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for card in pool:
		var duplicate := false
		for selected in excluded:
			if str(selected.get("id", "")) == str(card.get("id", "")):
				duplicate = true
				break
		if not duplicate:
			candidates.append(card)
	if candidates.is_empty():
		return {}

	var total_weight := 0.0
	for card in candidates:
		total_weight += _rarity_weight(card)
	var roll := randf() * total_weight
	for card in candidates:
		roll -= _rarity_weight(card)
		if roll <= 0.0:
			return card.duplicate(true)
	return candidates.back().duplicate(true)

func _rarity_weight(card: Dictionary) -> float:
	var rarity := str(card.get("rarity", "common"))
	var level := maxi(int(GameManager.player_level), 1)
	var progress := clampf(float(level - 1) / 19.0, 0.0, 1.0)
	match rarity:
		"common": return lerpf(7.0, 4.0, progress)
		"uncommon": return lerpf(2.5, 3.8, progress)
		"rare": return lerpf(0.45, 1.8, progress)
		_: return float(RARITY_WEIGHTS.get(rarity, 1.0))
