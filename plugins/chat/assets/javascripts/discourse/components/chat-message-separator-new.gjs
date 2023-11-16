import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";

export default class extends Component {
  <template>
    {{#if (and @message.newest (not @message.formattedFirstMessageDate))}}
      <div class="chat-message-separator-new">
        <div class="chat-message-separator__text-container">
          <span class="chat-message-separator__text">
            {{i18n "chat.last_visit"}}
          </span>
        </div>

        <div class="chat-message-separator__line-container">
          <div class="chat-message-separator__line"></div>
        </div>
      </div>
    {{/if}}
  </template>
}
