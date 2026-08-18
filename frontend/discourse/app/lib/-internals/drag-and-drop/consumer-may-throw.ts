import { next } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";
import { reportClientError } from "discourse/lib/report-client-error";

/**
 * Calls a consumer callback that is allowed to throw, so nothing it throws reaches the
 * caller.
 *
 * The library calls us from inside its own event dispatch and reaches its end-of-drag
 * cleanup on the next statement, unguarded. An escaping exception skips that cleanup and
 * is reported as uncaught, where nothing in the application can handle it.
 *
 * The source's deferred end-of-drag pair needs the same guard: its second callback and its
 * waiting teardown both still have to run.
 *
 * Reported through `discourse-error`, which attributes it to whichever theme or plugin it
 * came from. Under test it is raised as well, so a consumer's mistake fails the test it
 * happened in rather than passing quietly.
 *
 * @param run - The consumer callback.
 * @param fallback - Returned when it throws. Omit for a callback returning nothing. Give a
 *   gate the conservative answer, since a gate that threw has decided nothing.
 */
export function consumerMayThrow<T>(run: () => T, fallback?: T): T | undefined {
  try {
    return run();
  } catch (error) {
    reportClientError(error, "broken_drag_and_drop_alert");
    if (isTesting()) {
      // Thrown here, the library would skip the cleanup that ends the drag, and
      // it starts no new drag while it still thinks one is running.
      next(() => {
        throw error;
      });
    }
    return fallback;
  }
}
