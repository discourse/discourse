import KeyValueStore from "discourse/lib/key-value-store";

const keyValueStore = new KeyValueStore("discourse_emojis_");
const EMOJI_USAGE = "emojiUsage";
const EMOJI_SELECTED_DIVERSITY = "emojiSelectedDiversity";
const TRACKED_EMOJIS = 15;

export default class EmojiStore {
  constructor(name) {
    this.store = new KeyValueStore("discourse_emojis_");

    this._setup();
  }

  get diversity() {
    return this.store.getObject(EMOJI_SELECTED_DIVERSITY) || 1;
  }

  set diversity(value) {
    this.store.setObject({ key: EMOJI_SELECTED_DIVERSITY, value });
  }

  get favorites() {
    return this.store.getObject(EMOJI_USAGE) || [];
  }

  set favorites(value) {
    this.store.setObject({ key: EMOJI_USAGE, value });
  }

  track(code) {
    const normalizedCode = code.replace(/(^:)|(:$)/g, "");
    const recent = this.favorites.filter(r => r !== normalizedCode);
    recent.unshift(normalizedCode);
    recent.length = Math.min(recent.length, TRACKED_EMOJIS);
    this.favorites = recent;
  }

  static reset() {
    const store = new KeyValueStore("discourse_emojis_");
    store.setObject({ key: EMOJI_USAGE, value: [] });
    store.setObject({ key: EMOJI_SELECTED_DIVERSITY, value: 1 });
  }

  _setup() {
    if (!this.store.getObject(EMOJI_USAGE)) {
      this.favorites = [];
    }
  }
}
