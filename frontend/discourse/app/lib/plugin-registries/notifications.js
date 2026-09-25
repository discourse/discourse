const DEFAULT_LIMIT = 60;
let limit = DEFAULT_LIMIT;

export const beforeLoadMoreCallbacks = [];

export function addBeforeLoadMoreCallback(fn) {
  beforeLoadMoreCallbacks.push(fn);
}

export function setNotificationsLimit(newLimit) {
  limit = newLimit;
}

export function notificationsLimit() {
  return limit;
}
