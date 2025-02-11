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
    {{#if this.isCollapsible}}
      <div class="chat-message-text">
        <ChatMessageCollapser
          @cooked={{@cooked}}
          @decorate={{@decorate}}
          @uploads={{@uploads}}
          @onToggleCollapse={{@onToggleCollapse}}
        />
      </div>
    {{else}}
      <DecoratedHtml
        @html={{htmlSafe @cooked}}
        @decorate={{@decorate}}
        @className="chat-message-text chat-cooked"
      />
    {{/if}}

    {{#if this.isEdited}}
      <span class="chat-message-edited">({{i18n "chat.edited"}})</span>
    {{/if}}
  </template>
}
