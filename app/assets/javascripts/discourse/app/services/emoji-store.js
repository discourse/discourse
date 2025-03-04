import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export const SKIN_TONE_STORE_KEY = "emojiSelectedDiversity";
export const STORE_NAMESPACE = "discourse_emoji_reaction_";
export const LEGACY_USER_EMOJIS_STORE_KEY = "topic_emojiUsage";
export const USER_EMOJIS_STORE_KEY = "emoji_usage";
export const MAX_DISPLAYED_EMOJIS = 20;
export const MAX_TRACKED_EMOJIS = MAX_DISPLAYED_EMOJIS * 2;
export const DEFAULT_DIVERSITY = 1;

export default class EmojiStore extends Service {
  @service site;
  @service siteSettings;

  @tracked list;

  store = new KeyValueStore(STORE_NAMESPACE);

  @tracked _diversity;
  @tracked _favorites;

  constructor() {
    super(...arguments);

    // TODO (joffrey): remove in 2026
    const legacy = this.store.getObject(LEGACY_USER_EMOJIS_STORE_KEY);
    if (legacy) {
      this.store.setObject({ key: USER_EMOJIS_STORE_KEY, value: legacy });
      this.store.remove(LEGACY_USER_EMOJIS_STORE_KEY);
    }
  }

  get diversity() {
    return (
      this._diversity ??
      this.store.getObject(SKIN_TONE_STORE_KEY) ??
      DEFAULT_DIVERSITY
    );
  }

  set diversity(value) {
    this._diversity = value;
    this.store.setObject({ key: SKIN_TONE_STORE_KEY, value });
  }

  trackEmoji(emoji) {
    const recentEmojis = this.#addEmoji(emoji);
    this.favorites = recentEmojis;
    return recentEmojis;
  }

  get favorites() {
    return this.#sortEmojisByFrequency(this.#recentEmojis)
      .filter((f) => !this.site.denied_emojis?.includes(f))
      .slice(0, MAX_DISPLAYED_EMOJIS);
  }

  set favorites(value) {
    this._favorites = value;
    this.#persistEmojis(value);
  }

  reset() {
    this.diversity = DEFAULT_DIVERSITY;
    this.favorites = [];
  }

  get #recentEmojis() {
    return this._favorites ?? this.store.getObject(USER_EMOJIS_STORE_KEY) ?? [];
  }

  #addEmoji(emoji) {
    const recentEmojis = this.#recentEmojis;
    recentEmojis.unshift(this.#normalizeEmojiCode(emoji));
    recentEmojis.length = Math.min(recentEmojis.length, MAX_TRACKED_EMOJIS);
    return recentEmojis;
  }

  #persistEmojis(value) {
    this.store.setObject({ key: USER_EMOJIS_STORE_KEY, value });
  }

  #normalizeEmojiCode(code) {
    return code.replace(/(^:)|(:$)/g, "");
  }

  #sortEmojisByFrequency(emojis = []) {
    const counters = emojis.reduce((obj, val) => {
      obj[val] = (obj[val] || 0) + 1;
      return obj;
    }, {});
    return Object.keys(counters).sort((a, b) => counters[b] - counters[a]);
  }
}
