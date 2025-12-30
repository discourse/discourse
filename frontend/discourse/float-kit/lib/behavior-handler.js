/**
 * Process an event handler behavior configuration.
 *
 * This pattern is used by trigger components to handle onPress events
 * with customizable default behaviors. Supports both function handlers
 * that can call changeDefault() and object configurations that merge
 * with defaults.
 *
 * @param {Object} options
 * @param {Event|null} options.nativeEvent - The native event that triggered the handler
 * @param {Object} options.defaultBehavior - Default behavior configuration
 * @param {Function|Object} [options.handler] - Handler function or configuration object
 * @returns {Object} The resolved behavior configuration
 *
 * @example
 * // With function handler
 * const behavior = processBehavior({
 *   nativeEvent: event,
 *   defaultBehavior: { forceFocus: true, runAction: true },
 *   handler: (e) => e.changeDefault({ forceFocus: false })
 * });
 *
 * @example
 * // With object configuration
 * const behavior = processBehavior({
 *   nativeEvent: event,
 *   defaultBehavior: { forceFocus: true, runAction: true },
 *   handler: { forceFocus: false }
 * });
 */
export function processBehavior({ nativeEvent, defaultBehavior, handler }) {
  let result = { ...defaultBehavior };

  if (handler) {
    if (typeof handler === "function") {
      const customEvent = {
        ...result,
        nativeEvent,
        changeDefault(changes) {
          result = { ...result, ...changes };
          Object.assign(this, changes);
        },
      };
      handler(customEvent);
    } else {
      result = { ...defaultBehavior, ...handler };
    }
  }

  return result;
}

