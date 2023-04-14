import Component from "@glimmer/component";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";
import { action } from "@ember/object";

export default class UserMenuItem extends Component {
  get className() {
    return this.#item.className;
  }

  get linkHref() {
    return this.#item.linkHref;
  }

  get linkTitle() {
    return this.#item.linkTitle;
  }

  get icon() {
    return this.#item.icon;
  }

  get label() {
    return this.#item.label;
  }

  get labelClass() {
    return this.#item.labelClass;
  }

  get description() {
    const description = this.#item.description;
    if (description) {
      if (typeof description === "string") {
        // do emoji unescape on all items
        return htmlSafe(emojiUnescape(escapeExpression(description)));
      }
      // it's probably an htmlSafe object, don't try to unescape emojis
      return description;
    }
  }

  get descriptionClass() {
    return this.#item.descriptionClass;
  }

  get topicId() {
    return this.#item.topicId;
  }

  get #item() {
    return this.args.item;
  }

  @action
  onClick(event) {
    return this.#item.onClick({
      event,
      closeUserMenu: this.args.closeUserMenu,
    });
  }
}
