import { isTesting } from "discourse/lib/environment";

const callbacks = [];

/**
 * @typedef {Object} OnBeforeVisibilityChangeContext
 * @property {string} nextVisibility - The visibility value the user is switching to
 *   (e.g. "public" or "group_restricted").
 * @property {string} previousVisibility - The visibility value before this change.
 * @property {object} category - The category being edited.
 * @property {Object} form - The Form API object for the edit category form.
 * @property {Object} [transientData] - Transient data from the Form wrapper, when available.
 */

/**
 * Registers a callback to run when the user changes the category visibility selection in the
 * category editor's General tab. Callbacks run in registration order. If any callback’s
 * resolved value is falsy, the new selection is not applied.
 *
 * The callback may be `async` (e.g. to show a modal and await the result). Return a **truthy**
 * value to allow the change, or a **falsy** value to block it. On thrown errors, the change is
 * blocked and an error is reported; in tests, the error is rethrown.
 *
 * @param {function(OnBeforeVisibilityChangeContext): (boolean|undefined|Promise<boolean|undefined>)} fn
 */
export function registerOnBeforeVisibilityChange(fn) {
  callbacks.push(fn);
}

/**
 * Clear registered callbacks. For tests.
 */
export function resetOnBeforeVisibilityChange() {
  callbacks.length = 0;
}

/**
 * @param {OnBeforeVisibilityChangeContext} ctx
 * @returns {Promise<boolean>}
 */
export async function runOnBeforeVisibilityChange(ctx) {
  for (const fn of callbacks) {
    try {
      const result = await fn(ctx);
      if (!result) {
        return false;
      }
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: {
            messageKey: "on_before_visibility_change_error",
            error,
          },
        })
      );
      if (isTesting()) {
        throw error;
      }
      return false;
    }
  }
  return true;
}
