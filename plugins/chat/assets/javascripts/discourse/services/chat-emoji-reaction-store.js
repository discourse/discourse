// This class is adapted from emoji-store class in core. We want to maintain separate emoji store for reactions in chat plugin.
// https://github.com/discourse/discourse/blob/892f7e0506f3a4d40d9a59a4c926ff0a2aa0947e/app/assets/javascripts/discourse/app/services/emoji-store.js

import KeyValueStore from "discourse/lib/key-value-store";
import Service from "@ember/service";

export default class ChatEmojiReactionStore extends Service {
  STORE_NAMESPACE = "discourse_chat_emoji_reaction_";
  MAX_DISPLAYED_EMOJIS = 20;
  MAX_TRACKED_EMOJIS = this.MAX_DISPLAYED_EMOJIS * 2;
  SKIN_TONE_STORE_KEY = "emojiSelectedDiversity";
  USER_EMOJIS_STORE_KEY = "emojiUsage";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  constructor() {
    super(...arguments);

    if (!this.store.getObject(this.USER_EMOJIS_STORE_KEY)) {
      this.storedFavorites = [];
    }
  }

  get diversity() {
    return this.store.getObject(this.SKIN_TONE_STORE_KEY) || 1;
  }

  set diversity(value = 1) {
    this.store.setObject({ key: this.SKIN_TONE_STORE_KEY, value });
    this.notifyPropertyChange("diversity");
  }

  get storedFavorites() {
    let value = this.store.getObject(this.USER_EMOJIS_STORE_KEY) || [];

    if (value.length < 1) {
      if (!this.siteSettings.default_emoji_reactions) {
        value = [];
      } else {
        value = this.siteSettings.default_emoji_reactions
          .split("|")
          .filter(Boolean);
      }

      this.store.setObject({ key: this.USER_EMOJIS_STORE_KEY, value });
    }

    return value;
  }

  set storedFavorites(value) {
    this.store.setObject({ key: this.USER_EMOJIS_STORE_KEY, value });
    this.notifyPropertyChange("favorites");
  }

  get favorites() {
    const computedStored = [
      ...new Set(this._frequencySort(this.storedFavorites)),
    ];

    return computedStored.slice(0, this.MAX_DISPLAYED_EMOJIS);
  }

  set favorites(value = []) {
    this.store.setObject({ key: this.USER_EMOJIS_STORE_KEY, value });
  }

  track(code) {
    const normalizedCode = code.replace(/(^:)|(:$)/g, "");
    let recent = this.storedFavorites;
    recent.unshift(normalizedCode);
    recent.length = Math.min(recent.length, this.MAX_TRACKED_EMOJIS);
    this.storedFavorites = recent;
  }

  reset() {
    this.store.setObject({ key: this.USER_EMOJIS_STORE_KEY, value: [] });
    this.store.setObject({ key: this.SKIN_TONE_STORE_KEY, value: 1 });
  }

  _frequencySort(array = []) {
    const counters = array.reduce((obj, val) => {
      obj[val] = (obj[val] || 0) + 1;
      return obj;
    }, {});
    return Object.keys(counters).sort((a, b) => counters[b] - counters[a]);
  }
}
