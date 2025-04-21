import Component from "@glimmer/component";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class Channel extends Component {
  @service currentUser;

  get tracking() {
    return this.args.item.tracking;
  }

  get isUrgent() {
    return this.args.item.model.isDirectMessageChannel
      ? this.hasUnreads || this.hasUrgent
      : this.hasUrgent;
  }

  get hasUnreads() {
    return this.tracking?.unreadCount > 0;
  }

  get hasUrgent() {
    return (
      this.tracking?.mentionCount > 0 ||
      this.tracking?.watchedThreadsUnreadCount > 0
    );
  }

  get hasUnreadThreads() {
    return this.args.item.unread_thread_count > 0;
  }

  get showIndicator() {
    return this.hasUnreads || this.hasUnreadThreads || this.hasUrgent;
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
