import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import Channel from "./channel";
import Group from "./group";
import ListAction from "./list-action";
import User from "./user";

export default class List extends Component {
  cantAddMoreMembersLabel = i18n(
    "chat.new_message_modal.cant_add_more_members"
  );

  componentForItem(type) {
    switch (type) {
      case "list-action":
        return ListAction;
      case "user":
        return User;
      case "group":
        return Group;
      case "channel":
        return Channel;
    }
  }

  @action
  handleEnter(item, event) {
    if (event.key !== "Enter") {
      return;
    }

    if (event.shiftKey && this.args.onShiftSelect) {
      this.args.onShiftSelect?.(item);
    } else {
      this.args.onSelect?.(item);
    }
  }

  @action
  handleClick(item, event) {
    if (event.shiftKey && this.args.onShiftSelect) {
      this.args.onShiftSelect?.(item);
    } else {
      this.args.onSelect?.(item);
    }
  }

  <template>
    {{#if @items}}
      <div class="chat-message-creator__list-container">
        {{#if @maxReached}}
          <div
            class="chat-message-creator__warning-max-members"
          >{{this.cantAddMoreMembersLabel}}</div>
        {{else}}
          <ul class="chat-message-creator__list">
            {{#each @items as |item|}}
              <li
                class={{concatClass
                  "chat-message-creator__list-item"
                  (if
                    (eq item.identifier @highlightedItem.identifier)
                    "-highlighted"
                  )
                }}
                {{on "click" (fn this.handleClick item)}}
                {{on "keypress" (fn this.handleEnter item)}}
                {{on "mousemove" (fn @onHighlight item)}}
                {{on "mouseleave" (fn @onHighlight null)}}
                role="button"
                tabindex="0"
                data-identifier={{item.identifier}}
                id={{item.id}}
              >
                {{component
                  (this.componentForItem item.type)
                  membersCount=@membersCount
                  item=item
                }}
              </li>
            {{/each}}
          </ul>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
