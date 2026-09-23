import { ajax } from "discourse/lib/ajax";

/**
 * Records an admin onboarding event as a staff action log.
 *
 * Errors are swallowed on purpose: losing an audit entry must never interrupt
 * the onboarding flow the admin is in the middle of.
 *
 * @param {"step_completed"|"completed"|"dismissed"} event
 * @param {string} [step] name of the step, for `step_completed` events
 * @param {string} [topicOption] option used to complete `start_posting`
 */
export async function logOnboardingEvent(event, step, topicOption) {
  try {
    await ajax("/admin/onboarding/events", {
      type: "POST",
      data: { event, step, topic_option: topicOption },
    });
  } catch {
    // intentionally ignored
  }
}
