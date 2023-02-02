import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class ChatDrawerSize extends Service {
  STORE_NAMESPACE = "discourse_chat_drawer_size_";
  MIN_HEIGHT = 300;
  MIN_WIDTH = 250;

  store = new KeyValueStore(this.STORE_NAMESPACE);

  getSize() {
    return {
      width: this.store.getObject("width") || 0,
      height: this.store.getObject("height") || 0,
    };
  }

  setSize({ width, height }) {
    this.store.setObject({
      key: "width",
      value: this.#min(width, this.MIN_WIDTH),
    });
    this.store.setObject({
      key: "height",
      value: this.#min(height, this.MIN_HEIGHT),
    });
  }

  #min(number, min) {
    return Math.max(number, min);
  }
}
