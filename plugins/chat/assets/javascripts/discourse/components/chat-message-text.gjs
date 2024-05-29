import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";
import { isCollapsible } from "discourse/plugins/chat/discourse/components/chat-message-collapser";
import ChatMessageCollapser from "./chat-message-collapser";

export default class ChatMessageText extends Component {
  get isEdited() {
    return this.args.edited ?? false;
  }

  get isCollapsible() {
    return isCollapsible(this.args.cooked, this.args.uploads);
  }

  <template>
    <div class="chat-message-text">
      {{#if this.isCollapsible}}
        <ChatMessageCollapser
          @cooked={{@cooked}}
          @uploads={{@uploads}}
          @onToggleCollapse={{@onToggleCollapse}}
        />
      {{else}}
        {{htmlSafe @cooked}}
      {{/if}}

      {{#if this.isEdited}}
        <span class="chat-message-edited">({{i18n "chat.edited"}})</span>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
