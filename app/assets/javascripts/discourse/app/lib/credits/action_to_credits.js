// Module related to cost of actions

const ACTION_PRICE_LIST = {
	createTopic: 2,
	reply: 1
}

export const getActionCost = (action) => {
	if (!(action in ACTION_PRICE_LIST)) return 0
	return ACTION_PRICE_LIST[action]
}