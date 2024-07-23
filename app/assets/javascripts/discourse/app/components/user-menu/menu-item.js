import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

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

  get iconComponent() {
    return this.#item.iconComponent;
  }

  get iconComponentArgs() {
    return this.#item.iconComponentArgs;
  }

  get endComponent() {
    return this.#item.endComponent;
  }

  get endOutletArgs() {
    return this.#item.endOutletArgs;
  }

  get note() {
    return this.#item.note;
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
