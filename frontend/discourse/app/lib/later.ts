import { later, type Timer } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";

/**
 * The wait that every scheduled call collapses to while the test suite is running.
 * Short enough not to slow a test down, but still a real turn of the run loop rather
 * than an immediate call, so ordering that depends on the delay is preserved.
 */
const TESTING_WAIT_MS = 10;

/**
 * Schedules a function on the run loop, exactly like Ember's `later`, except that
 * the wait collapses to {@link TESTING_WAIT_MS} while the test suite is running. A
 * timer scheduled for several seconds would otherwise make every test that waits on
 * it that slow.
 *
 * The shortening applies only when the final argument is a number, which is the
 * position `later` reads the wait from. Any other call shape is forwarded untouched,
 * as are all calls outside of tests.
 *
 * Accepts each of `later`'s call forms and, like it, returns a timer that can be
 * handed to `cancel`.
 */
function discourseLater(...args: unknown[]): Timer {
  // `later`'s overloads describe its individual call forms, none of which a
  // spread of unknowns can satisfy; this wrapper only relays the arguments.
  const relay = later as (...args: unknown[]) => Timer;

  if (isTesting() && typeof [...args].at(-1) === "number") {
    const shortenedArgs = args.slice(0, -1);
    shortenedArgs.push(TESTING_WAIT_MS);

    return relay(...shortenedArgs);
  } else {
    return relay(...args);
  }
}

export default discourseLater as typeof later;
