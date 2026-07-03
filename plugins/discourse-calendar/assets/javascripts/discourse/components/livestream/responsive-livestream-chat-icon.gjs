import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import MobileLivestreamChatIcon from "./mobile-livestream-chat-icon";

export default class ResponsiveLivestreamChatIcon extends Component {
  @service capabilities;
  @controller("topic") topicController;

  get shouldShow() {
    return (
      !this.capabilities.viewport.lg &&
      this.topicController?.model?.chat_channel_id
    );
  }

  <template>
    {{#if this.shouldShow}}
      <MobileLivestreamChatIcon />
    {{/if}}
  </template>
}
