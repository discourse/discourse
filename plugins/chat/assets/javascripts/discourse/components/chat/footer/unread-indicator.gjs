import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

const MAX_UNREAD_COUNT = 99;

export default class ChatFooterUnreadIndicator extends Component {
  @service chatTrackingStateManager;

  badgeType = this.args.messageType;

  get urgentCount() {
    if (this.badgeType === "channels") {
      return this.chatTrackingStateManager.publicChannelMentionCount;
    } else if (this.badgeType === "dms") {
      return this.chatTrackingStateManager.directMessageUnreadCount;
    } else {
      return 0;
    }
  }

  get unreadCount() {
    if (this.badgeType === "channels") {
      return this.chatTrackingStateManager.publicChannelUnreadCount;
    } else if (this.badgeType === "threads") {
      return this.chatTrackingStateManager.hasUnreadThreads ? 1 : 0;
    } else {
      return 0;
    }
  }

  get showUrgent() {
    return this.urgentCount > 0;
  }

  get showUnread() {
    return this.unreadCount > 0;
  }

  get urgentBadgeCount() {
    let totalCount = this.urgentCount;
    return totalCount > MAX_UNREAD_COUNT ? `${MAX_UNREAD_COUNT}+` : totalCount;
  }

  <template>
    {{#if this.showUrgent}}
      <div class="chat-channel-unread-indicator -urgent">
        <div class="chat-channel-unread-indicator__number">
          {{this.urgentBadgeCount}}
        </div>
      </div>
    {{else if this.showUnread}}
      <div class="chat-channel-unread-indicator"></div>
    {{/if}}
  </template>
}
