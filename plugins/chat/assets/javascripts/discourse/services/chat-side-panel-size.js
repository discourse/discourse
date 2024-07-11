import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class ChatSidePanelSize extends Service {
  STORE_NAMESPACE = "discourse_chat_side_panel_size_";
  MIN_WIDTH = 250;

  store = new KeyValueStore(this.STORE_NAMESPACE);

  @tracked _width = this.store.getObject("width");

  get width() {
    return this._width ?? this.MIN_WIDTH;
  }

  set width(width) {
    this.store.setObject({
      key: "width",
      value: this.#min(width, this.MIN_WIDTH),
    });
    this._width = this.#min(width, this.MIN_WIDTH);
  }

  #min(number, min) {
    return Math.max(number, min);
  }
}
