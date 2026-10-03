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
var at_war: bool = false
var war_score: float = 0.0
var war_years: int = 0
var trade_value: float = 0.0
var distance: float = 0.0
var event_history: Array[String] = []
var last_war_winner: int = -1

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
	economy_a: float,
	economy_b: float,
	technology_a: float,
	technology_b: float
) -> void:
	var economic_compatibility: float = (
		100.0
		- abs(economy_a - economy_b)
	)

	var technology_compatibility: float = (
		100.0
		- abs(technology_a - technology_b)
	)

	var compatibility: float = (
		economic_compatibility * 0.5
		+ technology_compatibility * 0.5
	)

	var relation_target: float = (
		compatibility - 50.0
	)

	# Le commerce et la confiance
	# influencent légèrement la relation.
	var trade_bonus: float = (
		trade * 0.10
	)

	var trust_bonus: float = (
		(trust - 50.0) * 0.10
	)

	relation_target += (
		trade_bonus
		+ trust_bonus
	)

	relation += (
		relation_target - relation
	) * 0.01

	relation = clamp(
		relation,
		-100.0,
		100.0
	)

	# Évolution de la confiance.
	if relation > 20.0:
		trust += 0.2
	else:
		trust -= 0.05

	# Un commerce important renforce
	# progressivement la confiance.
	if trade > 30.0:
		trust += 0.1

	trust = clamp(
		trust,
		0.0,
		100.0
	)

	# Calcul du commerce possible
	# en fonction de la distance.
	var distance_factor: float = clamp(
		1.0 - (distance / 800.0),
		0.0,
		1.0
	)

	var trade_target: float = 0.0

	if not at_war and relation > 30.0:
		trade_target = (
			100.0
			* distance_factor
		)

	trade += (
		trade_target - trade
	) * 0.05

	trade = clamp(
		trade,
		0.0,
		100.0
	)

	# Valeur économique réelle du commerce.
	trade_value = (
		trade
		* 0.5
		* min(
			(economy_a + economy_b) / 100.0,
			2.0
		)
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
	current_year: int,
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

	war_score += (
		power_difference * 0.01
	)

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a_id
		+ civilization_b_id
		+ current_year
	)

	war_score += rng.randf_range(
		-2.0,
		2.0
	)

	war_score = clamp(
		war_score,
		-100.0,
		100.0
	)

	if war_years >= 5:
		if war_score >= 40.0:
			return end_war(
				current_year,
				"victory_a"
			)

		if war_score <= -40.0:
			return end_war(
				current_year,
				"victory_b"
			)

	if war_years >= 10:
		return end_war(
			current_year,
			"peace"
		)

	return ""
