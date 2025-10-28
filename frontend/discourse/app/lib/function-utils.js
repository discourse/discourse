/**
 * Utility functions for safely invoking functions
 */

/**
 * Safely invokes a function with comprehensive error handling
 *
 * Handles synchronous errors, promise rejections, and non-function values gracefully.
 * Promise rejections are caught and logged to prevent unhandled rejection errors.
 *
 * @param {Function} fn - The function to invoke
 * @param {...any} args - Arguments to pass to the function
 * @returns {any} The function result, or undefined if fn is not a function or an error occurs
 */
export function safeInvoke(fn, ...args) {
  if (typeof fn !== "function") {
    return;
  }

  try {
    const result = fn(...args);

    // Handle promises - catch rejections to prevent unhandled errors
    if (result && typeof result.then === "function") {
      result.catch((e) => {
        // eslint-disable-next-line no-console
        console.error("Promise rejected: ", e);
      });
    }

    return result;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Invocation error: ", e);
  }
}
