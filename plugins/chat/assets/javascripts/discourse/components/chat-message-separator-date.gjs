import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import trackMessageSeparatorDate from "../modifiers/chat/track-message-separator-date";

export default class ChatMessageSeparatorDate extends Component {
  @action
  onDateClick() {
    return this.args.fetchMessagesByDate?.(
      this.args.message.firstMessageOfTheDayAt
    );
  }

  <template>
    {{#if @message.formattedFirstMessageDate}}
      <div
        class={{concatClass
          "chat-message-separator-date"
          (if @message.newest "with-last-visit")
        }}
        role="button"
        {{on "click" this.onDateClick passive=true}}
      >
        <div
          class="chat-message-separator__text-container"
          {{trackMessageSeparatorDate}}
        >
          <span class="chat-message-separator__text">
            {{@message.formattedFirstMessageDate}}

            {{#if @message.newest}}
              <span class="chat-message-separator__last-visit">
                <span
                  class="chat-message-separator__last-visit-separator"
                >-</span>
                {{i18n "chat.last_visit"}}
              </span>
            {{/if}}
          </span>
        </div>
      </div>

      <div class="chat-message-separator__line-container">
        <div class="chat-message-separator__line"></div>
      </div>
    {{/if}}
  </template>
}
