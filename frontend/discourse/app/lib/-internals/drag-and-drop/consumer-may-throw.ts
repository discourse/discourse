import { next } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";
import { reportClientError } from "discourse/lib/report-client-error";

/**
 * Calls a consumer callback that is allowed to throw, so nothing it throws
 * reaches the caller.
 *
 * The library calls consumer callbacks from inside its event dispatch, with
 * the end-of-drag cleanup on the next statement unguarded. An exception that
 * escapes skips that cleanup.
 *
 * The error is reported through `reportClientError`. Under test it is also
 * rethrown asynchronously, so the test it happened in still fails.
 *
 * @param run - The consumer callback.
 * @param fallback - Returned when the callback throws. Give a gate its
 *   conservative answer.
 */
export function consumerMayThrow<T>(run: () => T, fallback?: T): T | undefined {
  try {
    return run();
  } catch (error) {
    reportClientError(error, "broken_drag_and_drop_alert");
    if (isTesting()) {
      // Rethrown later so the library's cleanup on the next statement runs.
      next(() => {
        throw error;
      });
    }
    return fallback;
  }
}
