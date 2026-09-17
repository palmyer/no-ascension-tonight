extends Node

signal orb_collected(type: int)

signal level_up(new_level: int)
signal show_attunement_wheel
signal game_over
signal run_completed(final_wave: int)
signal boss_defeated(boss_id: String)
signal player_damaged(damage: float)
signal core_damaged(damage: float, current_integrity: float, max_integrity: float)
signal core_repaired(amount: float, current_integrity: float, max_integrity: float)
signal core_destroyed
signal special_used(skill_name: String, hit_count: int)
signal attribute_reaction(reaction_name: String, position: Vector2)
signal intermission_event_chosen(event_id: String)
signal card_acquired(card_id: String, rank: int)
## 打击反馈：镜头震动请求，strength 为像素级偏移幅度。
signal camera_shake_requested(strength: float)
## Android 系统返回键：统一转发为暂停/继续切换请求。
signal pause_toggle_requested
