import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class ChatDrawerSize extends Service {
  STORE_NAMESPACE = "discourse_chat_drawer_size_";
  MIN_HEIGHT = 300;
  MIN_WIDTH = 250;

  store = new KeyValueStore(this.STORE_NAMESPACE);

  get size() {
    return {
      width: this.store.getObject("width") || 400,
      height: this.store.getObject("height") || 530,
    };
  }

  set size({ width, height }) {
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
