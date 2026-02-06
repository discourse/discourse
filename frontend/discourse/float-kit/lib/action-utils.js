/**
 * Parse an action prop value to extract the action type.
 * Action can be a string ("present", "dismiss", "step") or an object { type, direction?, detent? }.
 *
 * @param {string|Object} action - The action prop value
 * @returns {string} The action type
 */
export function getActionType(action) {
  return typeof action === "object" ? action.type : action;
}

/**
 * Parse an action prop value to extract the step direction.
 *
 * @param {string|Object} action - The action prop value
 * @returns {string} The step direction ("up" or "down")
 */
export function getStepDirection(action) {
  return typeof action === "object" ? (action.direction ?? "up") : "up";
}

/**
 * Parse an action prop value to extract the target detent index.
 *
 * @param {string|Object} action - The action prop value
 * @returns {number|undefined} The detent index if specified
 */
export function getStepDetent(action) {
  return typeof action === "object" ? action.detent : undefined;
}
