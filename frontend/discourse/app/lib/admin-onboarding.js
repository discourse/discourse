import { ajax } from "discourse/lib/ajax";

/**
 * Records an admin onboarding event as a staff action log.
 *
 * Errors are swallowed on purpose: losing an audit entry must never interrupt
 * the onboarding flow the admin is in the middle of.
 *
 * @param {"step_completed"|"completed"|"dismissed"} event
 * @param {string} [step] name of the step, for `step_completed` events
 */
export async function logOnboardingEvent(event, step) {
  try {
    await ajax("/admin/onboarding/events", {
      type: "POST",
      data: { event, step },
    });
  } catch {
    // intentionally ignored
  }
}
