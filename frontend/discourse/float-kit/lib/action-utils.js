export function getActionType(action) {
  return action !== null && typeof action === "object" ? action.type : action;
}
export function getStepDirection(action) {
  return action !== null && typeof action === "object"
    ? (action.direction ?? "up")
    : "up";
}
export function getStepDetent(action) {
  return action !== null && typeof action === "object"
    ? action.detent
    : undefined;
}
