import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import KeyValueStore from "discourse/lib/key-value-store";

export const RECENT_ANY_REACTIONS_STORE_KEY = "recentAnyReactions";
export const RECENT_ANY_REACTIONS_STORE_NAMESPACE =
  "discourse_recent_any_reactions_";

export default class RecentAnyReactionsStore extends Service {
  @tracked recentReactions = new TrackedArray([]);

  store = new KeyValueStore(RECENT_ANY_REACTIONS_STORE_NAMESPACE);

  constructor() {
    super(...arguments);
    this.loadRecentReactions();
  }

  /**
   * Track a reaction made via "any reaction" feature
   * @param {string} emoji - The emoji that was used as a reaction
   */
  trackAnyReaction(emoji) {
    const normalizedEmoji = this.#normalizeEmojiCode(emoji);
    const recentReactions = this.#getRecentReactions();

    // Remove if already exists to avoid duplicates
    const filteredReactions = recentReactions.filter(
      (r) => r !== normalizedEmoji
    );

    // Add to beginning of array
    const updatedReactions = [normalizedEmoji, ...filteredReactions];

    // Limit to max count based on site setting
    const maxCount =
      this.siteSettings.discourse_reactions_recent_any_reactions_count || 6;
    const limitedReactions = updatedReactions.slice(0, maxCount);

    this.recentReactions = new TrackedArray(limitedReactions);
    this.#persistRecentReactions(limitedReactions);
  }

  /**
   * Get recent any reactions for display
   * @returns {Array} Array of recent emoji reactions
   */
  getRecentAnyReactions() {
    return this.recentReactions;
  }

  /**
   * Clear all recent any reactions
   */
  clearRecentReactions() {
    this.recentReactions = new TrackedArray([]);
    this.#persistRecentReactions([]);
  }

  /**
   * Load recent reactions from storage
   */
  loadRecentReactions() {
    const stored = this.store.getObject(RECENT_ANY_REACTIONS_STORE_KEY);
    this.recentReactions = new TrackedArray(stored || []);
  }

  #getRecentReactions() {
    return this.recentReactions.length > 0
      ? this.recentReactions
      : this.store.getObject(RECENT_ANY_REACTIONS_STORE_KEY) || [];
  }

  #persistRecentReactions(reactions) {
    this.store.setObject({
      key: RECENT_ANY_REACTIONS_STORE_KEY,
      value: reactions,
    });
  }

  #normalizeEmojiCode(code) {
    return code.replace(/(^:)|(:$)/g, "");
  }
}
