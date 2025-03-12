import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
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

  <template>
    <li class={{this.className}}>
      <a
        href={{this.linkHref}}
        title={{this.linkTitle}}
        {{on "click" this.onClick}}
      >
        {{#if this.iconComponent}}
          <this.iconComponent @data={{this.iconComponentArgs}} />
        {{else}}
          {{icon this.icon}}
        {{/if}}
        <div>
          {{#if this.label}}
            <span class={{concat "item-label " this.labelClass}}>
              {{this.label}}
            </span>
          {{/if}}
          {{#if this.description}}
            <span
              class={{concat "item-description " this.descriptionClass}}
              data-topic-id={{this.topicId}}
            >
              {{this.description}}
            </span>
          {{/if}}
        </div>

        {{#if this.endComponent}}
          <this.endComponent />
        {{/if}}
      </a>
      <PluginOutlet @name="menu-item-end" @outletArgs={{this.endOutletArgs}} />
    </li>
  </template>
}
