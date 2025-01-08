import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import KeyValueStore from "discourse/lib/key-value-store";

export const SKIN_TONE_STORE_KEY = "emojiSelectedDiversity";
export const STORE_NAMESPACE = "discourse_emoji_reaction_";
export const USER_EMOJIS_STORE_KEY = "emojiUsage";
export const MAX_DISPLAYED_EMOJIS = 20;
export const MAX_TRACKED_EMOJIS = MAX_DISPLAYED_EMOJIS * 2;
export const DEFAULT_DIVERSITY = 1;

export default class EmojiStore extends Service {
  @service siteSettings;

  @tracked list;

  store = new KeyValueStore(STORE_NAMESPACE);

  contexts = new TrackedObject();

  @tracked _diversity;

  get diversity() {
    return this._diversity ?? this.store.getObject(SKIN_TONE_STORE_KEY) ?? 1;
  }

  set diversity(value) {
    this._diversity = value;
    this.store.setObject({ key: SKIN_TONE_STORE_KEY, value });
  }

  trackEmojiForContext(emoji, context) {
    const recentEmojis = this.#addEmojiToContext(emoji, context);
    this.contexts[context] = new TrackedArray(recentEmojis);
    this.#persistRecentEmojisForContext(recentEmojis, context);
    return recentEmojis;
  }

  favoritesForContext(context) {
    return this.#sortEmojisByFrequency(
      this.#recentEmojisForContext(context)
    ).slice(0, MAX_DISPLAYED_EMOJIS);
  }

  reset() {
    Object.keys(this.contexts).forEach((context) => {
      this.resetContext(context);
    });
    this.diversity = DEFAULT_DIVERSITY;
  }

  resetContext(context) {
    this.contexts[context] = this.#defaultEmojis;
    this.#persistRecentEmojisForContext(this.#defaultEmojis, context);
  }

  get #defaultEmojis() {
    return this.siteSettings.default_emoji_reactions.split("|").filter(Boolean);
  }

  #recentEmojisForContext(context) {
    return this.contexts[context] ?? this.#defaultEmojis;
  }

  #addEmojiToContext(emoji, context) {
    const recentEmojis = this.#recentEmojisForContext(context);
    recentEmojis.unshift(this.#normalizeEmojiCode(emoji));
    recentEmojis.length = Math.min(recentEmojis.length, MAX_TRACKED_EMOJIS);
    return recentEmojis;
  }

  #persistRecentEmojisForContext(recentEmojis, context) {
    const key = this.#emojisStorekeyForContext(context);
    this.store.setObject({ key, value: recentEmojis });
  }

  #normalizeEmojiCode(code) {
    return code.replace(/(^:)|(:$)/g, "");
  }

  #emojisStorekeyForContext(context) {
    return `${context}_${USER_EMOJIS_STORE_KEY}`;
  }

  #sortEmojisByFrequency(emojis = []) {
    const counters = emojis.reduce((obj, val) => {
      obj[val] = (obj[val] || 0) + 1;
      return obj;
    }, {});
    return Object.keys(counters).sort((a, b) => counters[b] - counters[a]);
  }
}
