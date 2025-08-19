import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import DecoratedHtml from "discourse/components/decorated-html";
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
          @decorate={{@decorate}}
          @uploads={{@uploads}}
          @onToggleCollapse={{@onToggleCollapse}}
        />
      {{else}}
        <DecoratedHtml
          @html={{htmlSafe @cooked}}
          @decorate={{@decorate}}
          @className="chat-cooked"
        />
      {{/if}}

      {{#if this.isEdited}}
        <span class="chat-message-edited">({{i18n "chat.edited"}})</span>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
