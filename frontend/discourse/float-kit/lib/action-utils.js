export function getActionType(action) {
  return typeof action === "object" ? action.type : action;
}
export function getStepDirection(action) {
  return typeof action === "object" ? (action.direction ?? "up") : "up";
}
export function getStepDetent(action) {
  return typeof action === "object" ? action.detent : undefined;
}
