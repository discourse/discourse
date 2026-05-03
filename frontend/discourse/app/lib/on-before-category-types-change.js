import { isTesting } from "discourse/lib/environment";

const callbacks = [];

/**
 * @typedef {Object} OnBeforeCategoryTypesChangeContext
 * @property {Object[]} nextTypes - Normalized category type objects after the empty-to-discussion rule
 *   (id, name, description, icon).
 * @property {Object[]} previousTypes - Snapshot of the selection before this change (shallow-copied
 *   array, same object references as before).
 * @property {object} category - The category being edited.
 * @property {Object} form - The Form API object for the edit category form.
 * @property {Object} [transientData] - Transient data from the Form wrapper, when available.
 */

/**
 * Registers a callback to run when the user changes category type selection in the
 * simplified category editor (upsert "general" tab). When `enable_simplified_category_creation` is
 * on, the callback runs in registration order. If any callback’s resolved value is falsy, the new
 * selection is not applied.
 *
 * The callback may be `async` (e.g. to show a modal and await the result). Return a **truthy**
 * value to allow the change, or a **falsy** value to block it. On thrown errors, the change is
 * blocked and an error is reported; in tests, the error is rethrown.
 *
 * @param {function(OnBeforeCategoryTypesChangeContext): (boolean|undefined|Promise<boolean|undefined>)} fn
 */
export function registerOnBeforeCategoryTypesChange(fn) {
  callbacks.push(fn);
}

/**
 * Clear registered callbacks. For tests.
 */
export function resetOnBeforeCategoryTypesChange() {
  callbacks.length = 0;
}

/**
 * @param {OnBeforeCategoryTypesChangeContext} ctx
 * @returns {Promise<boolean>}
 */
export async function runOnBeforeCategoryTypesChange(ctx) {
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
            messageKey: "on_before_category_types_change_error",
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
