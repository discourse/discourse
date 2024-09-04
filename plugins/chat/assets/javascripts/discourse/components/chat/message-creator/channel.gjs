import Component from "@glimmer/component";
import { service } from "@ember/service";
import { gt, not } from "truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class Channel extends Component {
  @service currentUser;

  get isUrgent() {
    return (
      this.args.item.model.isDirectMessageChannel ||
      (this.args.item.model.isCategoryChannel &&
        this.args.item.model.tracking.mentionCount > 0) ||
      (this.args.item.model.isCategoryChannel &&
        this.args.item.model.tracking.watchedThreadsUnreadCount > 0)
    );
  }

  <template>
    <div
      class="chat-message-creator__chatable -category-channel"
      data-disabled={{not @item.enabled}}
    >
      <ChannelTitle
        @channel={{@item.model}}
        @isUnread={{gt @item.tracking.unreadCount 0}}
        @isUrgent={{this.isUrgent}}
      />
    </div>
  </template>
}
