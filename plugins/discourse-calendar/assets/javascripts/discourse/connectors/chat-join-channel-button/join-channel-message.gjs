import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class JoinChannelMessage extends Component {
  @service embeddableChat;

  get shouldRenderJoinText() {
    return (
      this.embeddableChat.topicHasLivestream &&
      this.embeddableChat.chatChannelId
    );
  }

  <template>
    {{#if this.shouldRenderJoinText}}
      <div class="livestream-join-channel-message">
        <h2>
          {{i18n "discourse_calendar.livestream.chat.join_channel_header"}}
        </h2>
        <p>
          {{i18n "discourse_calendar.livestream.chat.join_channel_message"}}
        </p>
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
