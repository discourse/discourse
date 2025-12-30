import { DEBUG } from "@glimmer/env";

/**
 * Raises an error in dev/test environments, logs a warning in production.
 * This prevents crashes in production while still alerting developers to issues.
 *
 * @param {string} message - The error message
 * @throws {Error} In DEBUG mode
 */
export function raiseBlockError(message) {
  if (DEBUG) {
    throw new Error(message);
  } else {
    // eslint-disable-next-line no-console
    console.warn(`[Blocks] ${message}`);
  }
}
