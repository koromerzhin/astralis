class_name RelationData
extends RefCounted

const STATUS_HOSTILE := "hostile"
const STATUS_TENSE := "tendue"
const STATUS_NEUTRAL := "neutre"
const STATUS_FRIENDLY := "amicale"
const STATUS_ALLIED := "alliee"

var civilization_a_id: int
var civilization_b_id: int
var relation: float = 0.0
var trade: float = 0.0
var trust: float = 50.0
var alliance: bool = false
var at_war: bool = false
var war_score: float = 0.0
var war_years: int = 0
var trade_value: float = 0.0
var distance: float = 0.0
var event_history: Array[String] = []
var last_war_winner: int = -1
var revenge_a: float = 0.0
var revenge_b: float = 0.0
var war_ended_year: int = -1

func initialize(
	first_civilization_id: int,
	second_civilization_id: int,
	relation_seed: int,
	relation_distance: float
) -> void:
	civilization_a_id = first_civilization_id
	civilization_b_id = second_civilization_id
	distance = relation_distance

	var rng := RandomNumberGenerator.new()
	rng.seed = relation_seed

	relation = rng.randf_range(
		-20.0,
		20.0
	)

	trust = rng.randf_range(
		30.0,
		70.0
	)

	trade = 0.0
	trade_value = 0.0

func simulate_year(
	civilization_a_economy: float,
	civilization_a_technology: float,
	civilization_b_economy: float,
	civilization_b_technology: float,
	civilization_a: CivilizationData = null,
	civilization_b: CivilizationData = null
) -> void:
	if at_war:
		return

	var relation_change: float = 0.0

	# Économie et technologie favorisent légèrement
	# des relations stables.
	relation_change += (
		(
			civilization_a_economy
			+ civilization_b_economy
		) - 100.0
	) * 0.002

	relation_change += (
		(
			civilization_a_technology
			+ civilization_b_technology
		) - 100.0
	) * 0.001

	# Personnalité de la civilisation A.
	if civilization_a != null:
		relation_change += get_personality_pressure(
			civilization_a,
			civilization_b
		)

	# Personnalité de la civilisation B.
	if civilization_b != null:
		relation_change += get_personality_pressure(
			civilization_b,
			civilization_a
		)

	# Le commerce existant améliore progressivement
	# les relations.
	relation_change += trade * 0.01

	# La confiance facilite l'amélioration des relations.
	relation_change += (
		trust - 50.0
	) * 0.01

	# Une relation déjà très mauvaise évolue plus lentement
	# vers une situation positive.
	if relation < -60.0:
		relation_change *= 0.5

	# Une relation très positive devient naturellement stable.
	if relation > 70.0:
		relation_change *= 0.5

	relation += relation_change

	relation = clamp(
		relation,
		-100.0,
		100.0
	)

	# La confiance suit progressivement la relation.
	var trust_target: float = (
		relation + 100.0
	) * 0.5

	trust += (
		trust_target - trust
	) * 0.02

	trust = clamp(
		trust,
		0.0,
		100.0
	)

func get_relation_status() -> String:
	if relation <= -60.0:
		return STATUS_HOSTILE

	if relation <= -20.0:
		return STATUS_TENSE

	if relation < 20.0:
		return STATUS_NEUTRAL

	if relation < 60.0:
		return STATUS_FRIENDLY

	return STATUS_ALLIED

func get_trade_status() -> String:
	if trade < 1.0:
		return "aucun"

	if trade < 25.0:
		return "faible"

	if trade < 60.0:
		return "modere"

	return "important"

func simulate_event(
	current_year: int,
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> String:
	var event_seed: int = (
		civilization_a.seed
		+ civilization_b.seed
		+ current_year
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = event_seed

	var event_chance: float = rng.randf()

	if event_chance > 0.15:
		return ""

	if trade > 20.0 and relation > 20.0:
		var trade_success: float = rng.randf()

		if trade_success < 0.6:
			relation += 2.0
			trust += 3.0

			var message: String = (
				"Échange commercial réussi entre "
				+ civilization_a.name
				+ " et "
				+ civilization_b.name
				+ "."
			)

			_add_event_to_history(
				current_year,
				message
			)

			return message

	if technology_a_is_compatible(
		civilization_a,
		civilization_b
	):
		var technology_event: float = rng.randf()

		if technology_event < 0.4:
			relation += 3.0
			trust += 2.0

			var message: String = (
				"Coopération technologique entre "
				+ civilization_a.name
				+ " et "
				+ civilization_b.name
				+ "."
			)

			_add_event_to_history(
				current_year,
				message
			)

			return message

	if relation < 0.0:
		var tension_event: float = rng.randf()

		if tension_event < 0.5:
			relation -= 3.0
			trust -= 2.0

			var message: String = (
				"Tension économique entre "
				+ civilization_a.name
				+ " et "
				+ civilization_b.name
				+ "."
			)

			_add_event_to_history(
				current_year,
				message
			)

			return message

	var incident_event: float = rng.randf()

	if incident_event < 0.2:
		relation -= 5.0
		trust -= 4.0

		var message: String = (
			"Incident diplomatique entre "
			+ civilization_a.name
			+ " et "
			+ civilization_b.name
			+ "."
		)

		_add_event_to_history(
			current_year,
			message
		)

		return message

	return ""

func technology_a_is_compatible(
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> bool:
	var technology_difference: float = abs(
		civilization_a.technology
		- civilization_b.technology
	)

	return technology_difference <= 25.0

func _add_event_to_history(
	current_year: int,
	message: String
) -> void:
	event_history.append(
		"Année "
		+ str(current_year)
		+ " : "
		+ message
	)

	if event_history.size() > 20:
		event_history.pop_front()

func is_hostile() -> bool:
	return relation <= -60.0

func is_friendly() -> bool:
	return relation >= 20.0
	
func is_allied() -> bool:
	return relation >= 60.0 and trust >= 60.0

func start_war(
	current_year: int
) -> String:
	last_war_winner = -1
	if at_war:
		return ""

	at_war = true
	war_score = 0.0
	war_years = 0

	trade = 0.0
	trade_value = 0.0

	var message := (
		"Guerre entre les civilisations #"
		+ str(civilization_a_id)
		+ " et #"
		+ str(civilization_b_id)
		+ "."
	)

	_add_event_to_history(
		current_year,
		message
	)

	return message

func end_war(
	current_year: int,
	result: String
) -> String:
	if not at_war:
		return ""

	at_war = false

	var message := ""

	match result:
		"victory_a":
			relation += 15.0
			trust += 5.0

			message = (
				"Victoire de la civilisation #"
				+ str(civilization_a_id)
				+ " contre la civilisation #"
				+ str(civilization_b_id)
				+ "."
			)

		"victory_b":
			relation += 15.0
			trust += 5.0

			message = (
				"Victoire de la civilisation #"
				+ str(civilization_b_id)
				+ " contre la civilisation #"
				+ str(civilization_a_id)
				+ "."
			)

		"peace":
			relation += 5.0
			trust += 2.0

			message = (
				"Paix négociée entre les civilisations #"
				+ str(civilization_a_id)
				+ " et #"
				+ str(civilization_b_id)
				+ "."
			)

		_:
			message = (
				"Fin du conflit entre les civilisations #"
				+ str(civilization_a_id)
				+ " et #"
				+ str(civilization_b_id)
				+ "."
			)
	if result == "victory_a":
		last_war_winner = civilization_a_id
	elif result == "victory_b":
		last_war_winner = civilization_b_id
	else:
		last_war_winner = -1

	war_score = 0.0
	war_years = 0

	relation = clamp(
		relation,
		-100.0,
		100.0
	)

	trust = clamp(
		trust,
		0.0,
		100.0
	)

	_add_event_to_history(
		current_year,
		message
	)

	return message

func simulate_war_year(
	current_year_value: int,
	military_power_a: float,
	military_power_b: float
) -> String:
	if not at_war:
		return ""

	war_years += 1

	var power_difference: float = (
		military_power_a
		- military_power_b
	)

	var total_power: float = (
		military_power_a
		+ military_power_b
	)

	if total_power <= 0.0:
		return ""

	var power_ratio: float = (
		power_difference
		/ total_power
	)

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a_id * 31
		+ civilization_b_id * 17
		+ current_year_value * 997
	)

	var yearly_variation: float = (
		rng.randf_range(
			-0.05,
			0.05
		)
	)

	var score_change: float = (
		power_ratio * 10.0
		+ yearly_variation
	)

	war_score += score_change

	war_score = clamp(
		war_score,
		-100.0,
		100.0
	)

	# -------------------------------------------------
	# VICTOIRE DU CAMP A
	# -------------------------------------------------

	if war_score >= 100.0:
		last_war_winner = civilization_a_id
		at_war = false

		war_ended_year = current_year_value

		revenge_a = 0.0
		revenge_b = 100.0

		relation = min(
			relation,
			-20.0
		)

		trust = min(
			trust,
			25.0
		)

		event_history.append(
			"Année "
			+ str(current_year_value)
			+ " : victoire du camp A."
		)

		if event_history.size() > 20:
			event_history.pop_front()

		return (
			"Victoire de la civilisation #"
			+ str(civilization_a_id)
			+ " après "
			+ str(war_years)
			+ " ans de guerre."
		)

	# -------------------------------------------------
	# VICTOIRE DU CAMP B
	# -------------------------------------------------

	if war_score <= -100.0:
		last_war_winner = civilization_b_id
		at_war = false

		war_ended_year = current_year_value

		revenge_a = 100.0
		revenge_b = 0.0

		relation = min(
			relation,
			-20.0
		)

		trust = min(
			trust,
			25.0
		)

		event_history.append(
			"Année "
			+ str(current_year_value)
			+ " : victoire du camp B."
		)

		if event_history.size() > 20:
			event_history.pop_front()

		return (
			"Victoire de la civilisation #"
			+ str(civilization_b_id)
			+ " après "
			+ str(war_years)
			+ " ans de guerre."
		)

	# -------------------------------------------------
	# PAIX NÉGOCIÉE
	# -------------------------------------------------

	if war_years >= 30:
		var final_war_score: float = war_score

		last_war_winner = -1
		at_war = false

		war_ended_year = current_year_value

		# Aucun vainqueur clair :
		# les deux civilisations conservent
		# une certaine rancune.
		revenge_a = 25.0
		revenge_b = 25.0

		relation = min(
			relation,
			-10.0
		)

		trust = min(
			trust,
			35.0
		)

		event_history.append(
			"Année "
			+ str(current_year_value)
			+ " : paix négociée."
		)

		if event_history.size() > 20:
			event_history.pop_front()

		if abs(final_war_score) < 20.0:
			return (
				"Paix négociée après "
				+ str(war_years)
				+ " ans de guerre."
			)

		if final_war_score > 0.0:
			return (
				"Paix négociée après "
				+ str(war_years)
				+ " ans : avantage militaire du camp A."
			)

		return (
			"Paix négociée après "
			+ str(war_years)
			+ " ans : avantage militaire du camp B."
		)

	return ""

func get_diplomatic_status() -> String:
	if at_war:
		return STATUS_HOSTILE

	if alliance:
		return STATUS_ALLIED

	if relation <= -60.0:
		return STATUS_HOSTILE

	if relation <= -20.0:
		return STATUS_TENSE

	if relation < 30.0:
		return STATUS_NEUTRAL

	if relation < 70.0:
		return STATUS_FRIENDLY

	return STATUS_FRIENDLY

func can_form_alliance() -> bool:
	if at_war:
		return false

	if alliance:
		return false

	if relation < 70.0:
		return false

	if trust < 70.0:
		return false

	return true


func can_break_alliance() -> bool:
	if not alliance:
		return false

	if at_war:
		return true

	if relation < 40.0:
		return true

	if trust < 40.0:
		return true

	return false

func join_war(current_year_value: int) -> String:
	if at_war:
		return ""

	at_war = true
	war_score = 0.0
	war_years = 0
	last_war_winner = -1

	event_history.append(
		"Année "
		+ str(current_year_value)
		+ " : entrée en guerre."
	)

	if event_history.size() > 20:
		event_history.pop_front()

	return (
		"Entrée en guerre en "
		+ str(current_year_value)
	)

func get_personality_pressure(
	civilization: CivilizationData,
	other_civilization: CivilizationData
) -> float:
	if civilization == null:
		return 0.0

	if other_civilization == null:
		return 0.0

	var pressure: float = 0.0

	# Une civilisation agressive dégrade plus facilement
	# les relations avec ses voisins.
	pressure -= (
		civilization.aggression
		- 50.0
	) * 0.08

	# Le militarisme augmente également la tension.
	pressure -= (
		civilization.militarism
		- 50.0
	) * 0.05

	# La diplomatie améliore naturellement les relations.
	pressure += (
		civilization.diplomacy
		- 50.0
	) * 0.08

	# Le commerce favorise les relations pacifiques.
	pressure += (
		civilization.commerce
		- 50.0
	) * 0.04

	# L'isolationnisme réduit légèrement les interactions.
	pressure -= (
		civilization.isolationism
		- 50.0
	) * 0.03

	# L'expansionnisme crée une tension supplémentaire
	# lorsqu'une autre civilisation est proche.
	var distance_factor: float = clamp(
		1.0 - distance / 800.0,
		0.0,
		1.0
	)

	pressure -= (
		civilization.expansionism
		- 50.0
	) * 0.05 * distance_factor

	return pressure
