extends SceneTree
## Functional test: the Health component (hit points) and the player's HP bar.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_health.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var _changed := 0
var _last_changed := Vector2.ZERO
var _damaged := 0.0
var _healed := 0.0
var _died := 0


func _initialize() -> void:
	_run.call_deferred()


func _watch(health: Health) -> void:
	_changed = 0
	_damaged = 0.0
	_healed = 0.0
	_died = 0
	health.changed.connect(func(c: float, m: float) -> void:
		_changed += 1
		_last_changed = Vector2(c, m))
	health.damaged.connect(func(a: float) -> void: _damaged += a)
	health.healed.connect(func(a: float) -> void: _healed += a)
	health.died.connect(func() -> void: _died += 1)


func _make(max_hp: float = 100.0) -> Health:
	var health := Health.new()
	health.max_health = max_hp
	root.add_child(health)
	_watch(health)
	return health


func _run() -> void:
	kit = PlaytestKit.new(self)

	# 1. The component on its own.
	var h := _make()
	kit.check("a new Health starts full (100 of 100) and alive", h.current == 100.0 and h.fraction() == 1.0 and not h.is_dead(), "%s / %s" % [h.current, h.max_health])
	var taken := h.damage(30.0)
	kit.check("damage(30) takes 30 and says so (returned value, signal amounts, new total)",
			taken == 30.0 and h.current == 70.0 and _damaged == 30.0 and _changed == 1 and _last_changed == Vector2(70, 100) and is_equal_approx(h.fraction(), 0.7),
			"taken %s, current %s, damaged signal %s, changed x%d %s" % [taken, h.current, _damaged, _changed, _last_changed])
	var given := h.heal(50.0)
	kit.check("heal(50) at 70 gives only 30 (never above the maximum)", given == 30.0 and h.current == 100.0 and _healed == 30.0, "given %s, current %s, healed signal %s" % [given, h.current, _healed])
	var changes_before := _changed
	kit.check("healing a full owner gives 0 and emits nothing", h.heal(10.0) == 0.0 and _changed == changes_before and _healed == 30.0, "changed x%d" % _changed)

	# 2. Bad numbers never corrupt it and never emit a signal.
	h.damage(40.0)  # now 60
	changes_before = _changed
	var bad := []
	for amount in [NAN, INF, -INF, -5.0, 0.0]:
		bad.append([h.damage(amount), h.heal(amount)])
	kit.check("NaN, infinity, negative and zero amounts do nothing to damage() or heal()",
			h.current == 60.0 and _changed == changes_before and bad.all(func(pair): return pair[0] == 0.0 and pair[1] == 0.0) and not h.is_dead(), "current %s, results %s" % [h.current, bad])

	# 3. Dying: exactly once, no more damage or healing afterwards.
	_died = 0
	var last := h.damage(500.0)
	kit.check("overkill takes only what was left (60), ends at 0, dead, `died` fired once",
			last == 60.0 and h.current == 0.0 and h.is_dead() and h.fraction() == 0.0 and _died == 1, "taken %s, current %s, died x%d" % [last, h.current, _died])
	changes_before = _changed
	kit.check("a dead owner takes no more damage, cannot be healed, and `died` does not fire again",
			h.damage(10.0) == 0.0 and h.heal(10.0) == 0.0 and _died == 1 and _changed == changes_before and h.current == 0.0, "died x%d, current %s" % [_died, h.current])

	# 4. Revive: back to full, and it can die again (a second `died`).
	h.revive()
	kit.check("revive() brings a dead owner back to full hit points", not h.is_dead() and h.current == 100.0 and _last_changed == Vector2(100, 100), "current %s" % h.current)
	changes_before = _changed
	h.revive()
	kit.check("revive() on a living owner does nothing", _changed == changes_before and h.current == 100.0)
	h.damage(100.0)
	kit.check("after a revive it can die again (`died` x2 in total)", h.is_dead() and _died == 2, "died x%d" % _died)

	# 5. Other sizes: a 20-hp mob, and a nonsense maximum that is repaired.
	var mob := _make(20.0)
	mob.damage(5.0)
	kit.check("a 20-hp mob: 5 damage leaves 15 (fraction 0.75)", mob.current == 15.0 and is_equal_approx(mob.fraction(), 0.75), "%s" % mob.current)
	var odd := _make(-50.0)
	kit.check("a maximum below 1 is repaired to 1 (a zero maximum would divide by zero in fraction())", odd.max_health == 1.0 and odd.current == 1.0 and odd.fraction() == 1.0, "max %s current %s" % [odd.max_health, odd.current])
	var nan_max := _make(NAN)
	var inf_max := _make(INF)
	kit.check("a NaN or infinite maximum is repaired to the default 100 (not left as NaN)", nan_max.max_health == 100.0 and nan_max.current == 100.0 and inf_max.max_health == 100.0 and inf_max.current == 100.0, "NaN -> %s, INF -> %s" % [nan_max.max_health, inf_max.max_health])

	# 5b. set_max: the maximum can change after _ready and everything stays consistent.
	var m := _make(100.0)
	m.damage(50.0)
	m.set_max(40.0)
	kit.check("set_max(40) at 50 hp cuts hp down to 40 and says so (changed 40 / 40, fraction 1.0)", m.max_health == 40.0 and m.current == 40.0 and _last_changed == Vector2(40, 40) and m.fraction() == 1.0, "max %s current %s changed %s" % [m.max_health, m.current, _last_changed])
	m.set_max(200.0)
	kit.check("set_max(200) keeps the hp (40), emits changed (40 / 200) and the fraction is 0.2", m.current == 40.0 and _last_changed == Vector2(40, 200) and is_equal_approx(m.fraction(), 0.2), "current %s changed %s" % [m.current, _last_changed])
	changes_before = _changed
	m.set_max(NAN)
	m.set_max(INF)
	kit.check("set_max(NaN) and set_max(INF) are ignored (no change, no signal)", m.max_health == 200.0 and _changed == changes_before, "max %s" % m.max_health)
	m.set_max(-5.0)
	kit.check("set_max(-5) is repaired to 1", m.max_health == 1.0 and m.current == 1.0, "max %s current %s" % [m.max_health, m.current])
	m.damage(100.0)
	m.set_max(300.0)
	kit.check("set_max on a dead owner does not bring it back (still dead, 0 hp)", m.is_dead() and m.current == 0.0 and m.max_health == 300.0, "dead %s current %s" % [m.is_dead(), m.current])
	for node in [h, mob, odd, nan_max, inf_max, m]:
		node.free()

	# 6. The real player: a Health node, and an HP bar on its HUD that follows it.
	await kit.load_world()
	var player := kit.player
	var health := player.get_node_or_null("Health") as Health
	var hud := player.get_node("HUD") as InteractionPrompt
	kit.check("the player has a Health node with 100 hit points", health != null and health.max_health == 100.0 and health.current == 100.0)
	if health == null:
		kit.finish()
		return
	await kit.physics_frames(2)
	kit.check("the HUD shows a full bar: '100 / 100', fraction 1.0", hud.hp_text() == "100 / 100" and hud.hp_fraction() == 1.0, "'%s' %.2f" % [hud.hp_text(), hud.hp_fraction()])
	var bars := hud.find_children("*", "ProgressBar", true, false)
	var bar := bars.front() as Control if bars.size() == 1 else null
	var screen := player.get_viewport().get_visible_rect()
	kit.check("the bar is on screen (inside the window, not covering the top-left clock)", bar != null and screen.encloses(bar.get_global_rect()) and bar.get_global_rect().position.y >= 50.0,
			"%s inside %s" % [bar.get_global_rect() if bar else "no bar", screen])
	health.damage(25.0)
	kit.check("after 25 damage the HUD says '75 / 100' and draws the bar 75% full", hud.hp_text() == "75 / 100" and is_equal_approx(hud.hp_fraction(), 0.75), "'%s' %.2f" % [hud.hp_text(), hud.hp_fraction()])
	health.damage(74.6)  # 0.4 left: alive, so the number must not read 0
	kit.check("with 0.4 hit points left the player is alive and the HUD reads '1 / 100', not '0'", not health.is_dead() and hud.hp_text() == "1 / 100", "'%s' current %.2f" % [hud.hp_text(), health.current])
	# Since step 12 the player's own handler turns 0 hp into a respawn at full hp at once, so unplug it to look at the empty bar.
	var knock_out := Callable(player, "_on_died")
	health.died.disconnect(knock_out)
	health.damage(1.0)
	kit.check("at 0 the player is dead and the HUD reads '0 / 100' with an empty bar", health.is_dead() and hud.hp_text() == "0 / 100" and hud.hp_fraction() == 0.0, "'%s' %.2f" % [hud.hp_text(), hud.hp_fraction()])
	health.revive()
	health.died.connect(knock_out)
	kit.check("after a revive the HUD is full again", hud.hp_text() == "100 / 100" and hud.hp_fraction() == 1.0, "'%s'" % hud.hp_text())
	health.damage(1000.0)
	kit.check("with the knock-out handler plugged in, 0 hp is a respawn at full hp (alive, '100 / 100'): death is never a dead end", not health.is_dead() and health.current == 100.0 and hud.hp_text() == "100 / 100", "dead %s, hp %.0f, '%s'" % [health.is_dead(), health.current, hud.hp_text()])
	health.set_max(200.0)
	kit.check("after set_max(200) the HUD follows the new maximum: '100 / 200', half full", hud.hp_text() == "100 / 200" and is_equal_approx(hud.hp_fraction(), 0.5), "'%s' %.2f" % [hud.hp_text(), hud.hp_fraction()])
	health.set_max(100.0)
	kit.check("and back: set_max(100) reads '100 / 100' and full", hud.hp_text() == "100 / 100" and hud.hp_fraction() == 1.0, "'%s'" % hud.hp_text())

	kit.finish()
