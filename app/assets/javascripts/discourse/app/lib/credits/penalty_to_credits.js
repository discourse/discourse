// Module related to cost of penalties

const PENALTY_COST = {
	polarizedContent: 1,
	misinformation: 1,
	hateContent: 1
}

export const getPenaltyCost = (action) => {
	if (!(action in PENALTY_COST)) return 0
	return PENALTY_COST[action]
}