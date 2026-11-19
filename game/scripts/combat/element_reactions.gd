class_name ElementReactions
extends RefCounted
## Elements react with what an enemy already carries (arena tactics, user 2026-11-19). Your hit
## counts as your element even with a plain weapon swing. Statuses come from your own element,
## witches' circles and death bursts, and the fire pits.
##
##   Shatter:  any heavy on a frozen-over (Ice) enemy: double damage, ice shards hit those near it.
##   Ignite:   Fire on a poisoned enemy: the poison explodes.
##   Arc:      Lightning on a wet (Water) or iced enemy: it jumps to everyone wet or iced nearby, and others close.
##   Freeze:   Ice on a wet enemy: frozen solid at once.
##   Eruption: Stone on a burning enemy: molten blast, everyone near is knocked down.
## Reaction damage is Kind.CHAIN, so it never sets off another reaction or a lightning chain.

const SHATTER_RADIUS := 3.0
const IGNITE_RADIUS := 3.5
const ARC_RADIUS := 6.0
const ERUPTION_RADIUS := 3.0


## Called by Combat.deal for your direct hits on arena enemies, before the hit's own statuses land.
## Returns the reaction's name ("" = none), for tests and the popup.
static func react(target: Enemy, info: DamageInfo) -> String:
	var src: Node = info.source
	var element := info.damage_type
	if element == "Physical" and src != null and src.has_method("element"):
		element = src.element()
	var s := target.statuses
	var at := target.global_position
	if info.kind == DamageInfo.Kind.HEAVY and s.has("ice"):
		s.remove("ice")
		_hit(target, info.amount, "Ice", src)
		for e in Combat.enemies_in_radius(at, SHATTER_RADIUS, [target]):
			_hit(e, info.amount * 0.4, "Ice", src)
		ElementFx.area("Ice", at, SHATTER_RADIUS)
		return _popup(at, "SHATTER", "Ice")
	match element:
		"Fire":
			if s.has("poison"):
				s.remove("poison")
				for e in Combat.enemies_in_radius(at, IGNITE_RADIUS):
					_hit(e, info.amount * 1.5, "Fire", src, 8.0, at)
				ElementFx.area("Fire", at, IGNITE_RADIUS)
				Combat.shake(0.3)
				return _popup(at, "IGNITE", "Fire")
		"Lightning":
			if s.has("water") or s.has("ice"):
				s.remove("water")
				for e in Combat.enemies_in_radius(at, ARC_RADIUS, [target]):
					var soaked: bool = e.statuses.has("water") or e.statuses.has("ice")
					if soaked or e.global_position.distance_to(at) <= ARC_RADIUS * 0.5:
						ElementFx.beam("Lightning", at + Vector3.UP, e.global_position + Vector3.UP)
						_hit(e, info.amount * (0.9 if soaked else 0.5), "Lightning", src)
				return _popup(at, "ARC", "Lightning")
		"Ice":
			if s.has("water"):
				s.remove("water")
				target.freeze(2.0)
				return _popup(at, "FREEZE", "Ice")
		"Stone":
			if s.has("fire"):
				s.remove("fire")
				for e in Combat.enemies_in_radius(at, ERUPTION_RADIUS, [target]):
					_hit(e, info.amount * 0.8, "Stone", src)
					e.knock_down()
				_hit(target, info.amount * 0.8, "Stone", src)
				ElementFx.area("Stone", at, ERUPTION_RADIUS)
				Combat.shake(0.3)
				return _popup(at, "ERUPTION", "Stone")
	return ""


static func _hit(e: Node, amount: float, element: String, src: Node, knockback := 0.0, from := Vector3.INF) -> void:
	if not is_instance_valid(e) or e.is_dead():
		return
	var info := DamageInfo.make(amount, element, DamageInfo.Kind.CHAIN, src if is_instance_valid(src) else null)
	info.can_chain = false
	info.category = "Magic"
	if knockback > 0.0 and from != Vector3.INF:
		var away: Vector3 = (e as Node3D).global_position - from
		away.y = 0.0
		info.knockback = knockback
		info.knockback_dir = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	Combat.deal(e, info)


## The reaction's name pops up over the enemy in its element's color.
static func _popup(at: Vector3, text: String, element: String) -> String:
	var root: Node = Combat.effects_root
	if not is_instance_valid(root):
		return text
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72
	l.outline_size = 14
	l.pixel_size = 0.01
	l.no_depth_test = true
	l.modulate = ElementFx.color(element).lightened(0.3)
	root.add_child(l)
	l.global_position = at + Vector3.UP * 2.6
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", at + Vector3.UP * 3.6, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	return text
