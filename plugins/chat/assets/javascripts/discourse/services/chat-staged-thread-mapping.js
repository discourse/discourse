import KeyValueStore from "discourse/lib/key-value-store";
import Service from "@ember/service";

export default class ChatStagedThreadMapping extends Service {
  STORE_NAMESPACE = "discourse_chat_";
  KEY = "staged_thread";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  constructor() {
    super(...arguments);

    if (!this.store.getObject(this.USER_EMOJIS_STORE_KEY)) {
      this.storedFavorites = [];
    }
  }

  getMapping() {
    return JSON.parse(this.store.getObject(this.KEY) || "{}");
  }

  setMapping(id, stagedId) {
    const mapping = {};
    mapping[stagedId] = id;
    this.store.setObject({
      key: this.KEY,
      value: JSON.stringify(mapping),
    });
  }

  reset() {
    this.store.setObject({ key: this.KEY, value: "{}" });
  }
}
