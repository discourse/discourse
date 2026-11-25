import { ajax } from "discourse/lib/ajax";

export const STEP_COMPLETED_CHANNEL = "/admin-onboarding/step-completed";
export const AGENT_TAB_HIDDEN_KEY = "onboarding_agent_tab_hidden";
export const CONNECT_AGENT_STEP = "connect_agent";
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
 * Whether an onboarding step is completed, in this browser or, for steps that
 * finish outside it, as recorded by the server.
 *
 * @param {object} services
 * @param {import("discourse/models/user").default} [services.currentUser]
 * @param {import("discourse/services/key-value-store").default} services.keyValueStore
 * @param {string} step name of the step
 * @returns {boolean}
 */
export function isOnboardingStepCompleted(
  { currentUser, keyValueStore },
  step
) {
  return (
    !!keyValueStore.get(onboardingStepKey(step)) ||
    !!currentUser?.admin_onboarding_completed_steps?.includes(step)
  );
}

/**
 * Marks an onboarding step completed in this browser and announces it, so a
 * banner that stays mounted while hidden on other pages keeps its progress
 * count in step. Use it on its own for steps the server already recorded.
 *
 * @param {object} services
 * @param {import("discourse/services/app-events").default} services.appEvents
 * @param {import("discourse/services/key-value-store").default} services.keyValueStore
 * @param {string} step name of the step
 * @returns {boolean} whether this browser had already marked the step
 */
export function markOnboardingStepCompleted(
  { appEvents, keyValueStore },
  step
) {
  const key = onboardingStepKey(step);
  const alreadyCompleted = !!keyValueStore.get(key);
  keyValueStore.set({ key, value: true });
  appEvents.trigger("onboarding-step:completed", step);

  return alreadyCompleted;
}

/**
 * Marks an onboarding step completed and records it on the server.
 *
 * Only the first completion is recorded. Await it before reloading the page so
 * the audit write isn't cancelled in flight.
 *
 * @param {object} services
 * @param {import("discourse/services/app-events").default} services.appEvents
 * @param {import("discourse/services/key-value-store").default} services.keyValueStore
 * @param {string} step name of the step
 */
export async function completeOnboardingStep(services, step) {
  if (!markOnboardingStepCompleted(services, step)) {
    await logOnboardingEvent("step_completed", step);
  }
}
