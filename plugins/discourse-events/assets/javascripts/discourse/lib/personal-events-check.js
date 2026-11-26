// Checked once per user rather than per date range, so the view tabs stay put
// while paging through the calendar and switching between views
const checks = new WeakMap();

export const ATTENDANCE_CHANGE_EVENTS = [
  "calendar:create-invitee-status",
  "calendar:update-invitee-status",
  "calendar:invitee-left-event",
];

/**
 * @param {Object} user
 * @returns {boolean|undefined} The settled answer, if there is one.
 */
export function knownPersonalEvents(user) {
  return checks.get(user)?.value;
}

/**
 * @param {Object} api The `discourse-post-event-api` service.
 * @param {Object} user
 * @returns {Promise<boolean>} Whether the user attends any event.
 */
export function checkPersonalEvents(api, user) {
  let check = checks.get(user);
  if (!check) {
    check = {};
    check.promise = api
      .hasEvents({ attending_user: user.username })
      // Offering an empty view beats hiding one the user has events in
      .catch(() => true)
      .then((hasEvents) => (check.value = hasEvents));
    checks.set(user, check);
  }
  return check.promise;
}

export function forgetPersonalEvents(user) {
  checks.delete(user);
}
