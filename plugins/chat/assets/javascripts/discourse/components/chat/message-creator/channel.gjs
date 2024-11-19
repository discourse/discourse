import Component from "@glimmer/component";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class Channel extends Component {
  @service currentUser;

  get isUrgent() {
    return this.args.item.model.isDirectMessageChannel
      ? this.hasUnreads || this.hasUrgent
      : this.hasUrgent;
  }

  get hasUnreads() {
    return this.args.item.tracking.unreadCount > 0;
  }

  get hasUrgent() {
    return (
      this.args.item.tracking.mentionCount > 0 ||
      this.args.item.tracking.watchedThreadsUnreadCount > 0
    );
  }

  get showIndicator() {
    return this.hasUnreads || this.isUrgent;
  }

  <template>
    <div
      class="chat-message-creator__chatable -category-channel"
      data-disabled={{not @item.enabled}}
    >
      <ChannelTitle
        @channel={{@item.model}}
        @isUnread={{this.showIndicator}}
        @isUrgent={{this.isUrgent}}
      />
    </div>
  </template>
}
