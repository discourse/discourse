import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

const store = new KeyValueStore("discourse_chat_composer_");

/**
 * Whether chat composers show their formatting bar. Shared by the channel and
 * thread composers and remembered per user in this browser.
 */
export default class ChatFormattingBar extends Service {
  @service currentUser;

  @tracked shown = !!store.getObject(this.#key);

  get #key() {
    return `formatting_bar_${this.currentUser?.id}`;
  }

  toggle() {
    this.shown = !this.shown;
    store.setObject({ key: this.#key, value: this.shown });
  }
}
