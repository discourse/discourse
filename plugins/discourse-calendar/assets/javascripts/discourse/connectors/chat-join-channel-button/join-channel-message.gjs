import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class JoinChannelMessage extends Component {
  @service embeddableChat;
  @service siteSettings;
  @controller("topic") topicController;

  get shouldRenderJoinText() {
    const topic = this.topicController?.model;
    return (
      this.siteSettings.livestream_enabled &&
      topic?.chat_channel_id &&
      this.embeddableChat.topicHasLivestreamTag(topic)
    );
  }

  <template>
    {{#if this.shouldRenderJoinText}}
      <h2>
        {{i18n "discourse_calendar.livestream.chat.join_channel_header"}}
      </h2>
      <p>
        {{i18n "discourse_calendar.livestream.chat.join_channel_message"}}
      </p>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
