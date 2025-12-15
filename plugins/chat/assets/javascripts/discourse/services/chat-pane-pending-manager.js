import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

/**
 * Single source of truth for pending message counts across all chat contexts.
 * Tracks how many messages arrived while the user was scrolled away or inactive.
 *
 * A "context" is identified by a key like "channel-123" or "thread-456".
 * The service maintains per-context counts and a global total used for
 * document title badges.
 */
export default class ChatPanePendingManager extends Service {
  @service appEvents;

  /**
   * Total pending messages across all contexts. Used for document title count.
   *
   * @type {number}
   */
  @tracked totalPendingMessageCount = 0;

  /**
   * Per-context pending counts.
   *
   * @type {Map<string, number>}
   */
  #countsByContext = new Map();

  /**
   * Get the pending message count for a specific context.
   *
   * @param {string} contextKey - The context identifier (e.g. "channel-123")
   * @returns {number}
   */
  getCount(contextKey) {
    return this.#countsByContext.get(contextKey) || 0;
  }

  /**
   * Check if a context has any pending messages.
   *
   * @param {string} contextKey - The context identifier
   * @returns {boolean}
   */
  hasPending(contextKey) {
    return this.getCount(contextKey) > 0;
  }

  /**
   * Add to the pending count for a context and trigger notifications.
   *
   * @param {string} contextKey - The context identifier
   * @param {number} [count=1] - Number of messages to add
   */
  add(contextKey, count = 1) {
    if (!contextKey || count <= 0) {
      return;
    }

    const current = this.#countsByContext.get(contextKey) || 0;
    const changed = this.#setCount(contextKey, current + count);

    if (changed) {
      this.appEvents.trigger("notifications:changed");
    }
  }

  /**
   * Clear all pending messages for a context and trigger notifications.
   *
   * @param {string} contextKey - The context identifier
   */
  clear(contextKey) {
    if (!contextKey) {
      return;
    }

    const changed = this.#setCount(contextKey, 0);

    if (changed) {
      this.appEvents.trigger("notifications:changed");
    }
  }

  /**
   * Update the count for a context and sync the global total.
   *
   * @param {string} contextKey
   * @param {number} newCount
   * @returns {boolean} Whether the count actually changed
   */
  #setCount(contextKey, newCount) {
    const oldCount = this.#countsByContext.get(contextKey) || 0;

    if (newCount === oldCount) {
      return false;
    }

    if (newCount > 0) {
      this.#countsByContext.set(contextKey, newCount);
    } else {
      this.#countsByContext.delete(contextKey);
    }

    const delta = newCount - oldCount;
    this.totalPendingMessageCount = Math.max(
      0,
      this.totalPendingMessageCount + delta
    );

    return true;
  }
}
