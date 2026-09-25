export const pluginReviewableParams = {};
export const reviewableTypeLabels = {};
export const pluginActionModalClassMap = {};

export function addPluginReviewableParam(reviewableType, param) {
  pluginReviewableParams[reviewableType]
    ? pluginReviewableParams[reviewableType].push(param)
    : (pluginReviewableParams[reviewableType] = [param]);
}

export function registerReviewableActionModal(actionName, modalClass) {
  pluginActionModalClassMap[actionName] = modalClass;
}

export function registerReviewableTypeLabel(reviewableType, labelKey) {
  reviewableTypeLabels[reviewableType] = labelKey;
}
