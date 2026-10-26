extends RefCounted
## Cosmetic catalog. No costs, combat bonuses or external asset paths.
const DEFAULT := "frontier"
const ORDER := ["frontier", "forge", "aurora"]
const DEFINITIONS := {
	"frontier": {"name": "مدينة الصقيع", "description": "أسوار حجرية وأسقف ثلجية وحي سكني حول الفرن المركزي."},
	"forge": {"name": "حصن الجمر", "description": "طابع صناعي داكن، نحاس ومداخن إضافية حول قلب الفرن."},
	"aurora": {"name": "قلعة الشفق", "description": "أبراج جليدية وتفاصيل فيروزية مع بقاء الفرن مصدر الدفء."},
}


static func valid_id(id: String) -> String:
	return id if DEFINITIONS.has(id) else DEFAULT


static func mesh_path(id: String, team := "me") -> String:
	var safe_team: String = team if team in ["me", "ally", "enemy", "neutral"] else "me"
	return "res://assets/city_skins/%s_%s.glb" % [valid_id(id), safe_team]
