import { ajax } from "discourse/lib/ajax";

export const CREATE_CATEGORY_STEP = "create_category";

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
      data: { event, ...(step && { step }) },
    });
  } catch {
    // intentionally ignored
  }
}

/**
 * The storage key holding whether an onboarding step is completed.
 *
 * @param {string} step name of the step
 * @returns {string}
 */
export function onboardingStepKey(step) {
  return `onboarding_step_${step}`;
}

/**
 * Marks an onboarding step completed when the banner holding it isn't
 * rendered, so the step reads as done once the banner renders again.
 *
 * Only the first completion is audited. Await it before reloading the page so
 * the audit write isn't cancelled in flight.
 *
 * @param {import("discourse/services/key-value-store").default} keyValueStore
 * @param {string} step name of the step
 */
export async function completeOnboardingStep(keyValueStore, step) {
  const key = onboardingStepKey(step);
  const alreadyCompleted = !!keyValueStore.get(key);
  keyValueStore.set({ key, value: true });

  if (!alreadyCompleted) {
    await logOnboardingEvent("step_completed", step);
  }
}
