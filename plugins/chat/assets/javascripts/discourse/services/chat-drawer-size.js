import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class ChatDrawerSize extends Service {
  STORE_NAMESPACE = "discourse_chat_drawer_size_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  getSize() {
    return {
      width: this.store.getObject("width") || 0,
      height: this.store.getObject("height") || 0,
    };
  }

  setSize({ width, height }) {
    this.store.setObject({ key: "width", value: width });
    this.store.setObject({ key: "height", value: height });
  }
}
