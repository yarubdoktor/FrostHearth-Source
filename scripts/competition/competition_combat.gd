extends RefCounted
## Deterministic local combat resolution for previews. Not authoritative multiplayer.
const SCHEMA_VERSION := 1
const MIN_POWER := 0.0
const MAX_POWER := 1000000.0

static func resolve(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	if not _valid_force(attacker) or not _valid_force(defender):
		return {}
	var attack_power := _force_power(attacker)
	var defense_power := _force_power(defender)
	if attack_power <= 0.0 or defense_power <= 0.0:
		return {}
	var attacker_wins := attack_power > defense_power
	var ratio := attack_power / defense_power
	var attacker_loss_ratio := clampf(0.18 + defense_power / maxf(attack_power, 1.0) * 0.42, 0.18, 0.82)
	var defender_loss_ratio := clampf(0.22 + attack_power / maxf(defense_power, 1.0) * 0.48, 0.22, 0.88)
	if not attacker_wins:
		attacker_loss_ratio = clampf(0.38 + ratio * 0.28, 0.38, 0.66)
		defender_loss_ratio = clampf(0.10 + ratio * 0.20, 0.10, 0.30)
	var attacker_units := int(attacker.get("units", 0))
	var defender_units := int(defender.get("units", 0))
	var attacker_losses := mini(attacker_units, int(ceil(float(attacker_units) * attacker_loss_ratio)))
	var defender_losses := mini(defender_units, int(ceil(float(defender_units) * defender_loss_ratio)))
	return {
		"schema_version": SCHEMA_VERSION,
		"outcome": "victory" if attacker_wins else "defeat",
		"attacker_power": attack_power,
		"defender_power": defense_power,
		"power_ratio": ratio,
		"attacker_units_start": attacker_units,
		"defender_units_start": defender_units,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"attacker_units_remaining": attacker_units - attacker_losses,
		"defender_units_remaining": defender_units - defender_losses,
		"target_burns": attacker_wins,
		"source": "local_preview",
		"authoritative": false
	}

static func _force_power(force: Dictionary) -> float:
	var units := float(force.get("units", 0))
	var attack := float(force.get("attack", 1.0))
	var hero := float(force.get("hero_power", 0.0))
	var fortification := float(force.get("fortification", 0.0))
	return units * attack + hero + fortification

static func _valid_force(force: Dictionary) -> bool:
	var units := int(force.get("units", -1))
	var attack := float(force.get("attack", 1.0))
	var hero := float(force.get("hero_power", 0.0))
	var fortification := float(force.get("fortification", 0.0))
	if units < 0 or units > 1000000:
		return false
	for value in [attack, hero, fortification]:
		if not is_finite(value) or value < MIN_POWER or value > MAX_POWER:
			return false
	return units > 0 and attack > 0.0
