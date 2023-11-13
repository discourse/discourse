import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import gt from "truth-helpers/helpers/gt";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";

export default class Channel extends Component {
  @service currentUser;

  get isUrgent() {
    return (
      this.args.item.model.isDirectMessageChannel ||
      (this.args.item.model.isCategoryChannel &&
        this.args.item.model.tracking.mentionCount > 0)
    );
  }

  <template>
    <div class="chat-message-creator__chatable-category-channel">
      <ChatChannelTitle @channel={{@item.model}} />

      {{#if (gt @item.tracking.unreadCount 0)}}
        <div
          class={{concatClass "unread-indicator" (if this.isUrgent "-urgent")}}
        ></div>
      {{/if}}
    </div>
  </template>
}
