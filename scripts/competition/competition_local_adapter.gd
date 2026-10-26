extends RefCounted
## Read-only adapter from the existing city profile card to competition preview data.
## This adapter does not write saves and does not establish a trusted online identity.

const Contract = preload("res://scripts/competition/competition_contract.gd")


static func build_from_profile_card(card: Dictionary, season_id: String = "preview-season") -> Dictionary:
	var local_id := str(card.get("id", "")).strip_edges()
	if local_id.is_empty() or local_id == "0":
		return {}
	var profile := {
		"player_id": "local-profile-" + local_id,
		"display_name": str(card.get("name", "قائد مجهول")),
		"city_level": maxi(0, int(card.get("furnace", 0))),
		"power": maxi(0, int(card.get("power", 0))),
		"research_level": maxi(0, int(card.get("techs", 0))),
		"qualifier_points": 0,
		"qualifier_wins": 0,
		"matches_played": 0,
		"season_id": season_id
	}
	return Contract.build_local_preview(profile, {
		"city_level": profile["city_level"],
		"power": profile["power"],
		"research_level": profile["research_level"]
	})


static func build_from_game(season_id: String = "preview-season") -> Dictionary:
	## Game.profile_card() is read-only. Returned IDs are local placeholders, not server account IDs.
	if not is_instance_valid(Game):
		return {}
	var card: Dictionary = Game.profile_card()
	return build_from_profile_card(card, season_id)
