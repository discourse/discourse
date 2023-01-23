import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import { tracked } from "@glimmer/tracking";

export default class ChatDrawerSize extends Service {
  STORE_NAMESPACE = "discourse_chat_drawer_size_";

  store = new KeyValueStore(this.STORE_NAMESPACE);

  @tracked _height = 0;
  @tracked _width = 0;

  constructor() {
    super(...arguments);

    this.width = this.store.getObject("width") || 0;
    this.height = this.store.getObject("height") || 0;
  }

  get width() {
    return this._width;
  }

  set width(value) {
    this.store.setObject({ key: "width", value });
    this._width = value;
  }

  get height() {
    return this._height;
  }

  set height(value) {
    this.store.setObject({ key: "height", value });
    this._height = value;
  }
}
