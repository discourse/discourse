import Component from "@glimmer/component";
import { service } from "@ember/service";

const CHANNELS_TAB = "channels";
const DMS_TAB = "dms";
const STARRED_TAB = "starred";
const THREADS_TAB = "threads";
const MAX_UNREAD_COUNT = 99;

export const UnreadChannelsIndicator = <template>
  <FooterUnreadIndicator @badgeType={{CHANNELS_TAB}} />
</template>;

export const UnreadDirectMessagesIndicator = <template>
  <FooterUnreadIndicator @badgeType={{DMS_TAB}} />
</template>;

export const UnreadStarredIndicator = <template>
  <FooterUnreadIndicator @badgeType={{STARRED_TAB}} />
</template>;

export const UnreadThreadsIndicator = <template>
  <FooterUnreadIndicator @badgeType={{THREADS_TAB}} />
</template>;

export default class FooterUnreadIndicator extends Component {
  @service chatChannelsManager;
  @service chatTrackingStateManager;

  badgeType = this.args.badgeType;

  get urgentCount() {
    if (this.badgeType === CHANNELS_TAB) {
      return this.chatTrackingStateManager.publicChannelMentionCount;
    } else if (this.badgeType === DMS_TAB) {
      return (
        this.chatTrackingStateManager.directMessageUnreadCount +
        this.chatTrackingStateManager.directMessageMentionCount
      );
    } else if (this.badgeType === STARRED_TAB) {
      return this.starredChannelsUrgentCount;
    } else if (this.badgeType === THREADS_TAB) {
      return this.chatTrackingStateManager.watchedThreadsUnreadCount;
    } else {
      return 0;
    }
  }

  get unreadCount() {
    if (this.badgeType === CHANNELS_TAB) {
      return this.chatTrackingStateManager.publicChannelUnreadCount;
    } else if (this.badgeType === STARRED_TAB) {
      return this.starredChannelsUnreadCount;
    } else if (this.badgeType === THREADS_TAB) {
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

  // Calculate urgent count for starred channels (DMs + mentions from public channels)
  get starredChannelsUrgentCount() {
    return this.chatChannelsManager.starredChannels.reduce((count, channel) => {
      if (channel.isDirectMessageChannel) {
        // DM unreads are always urgent
        return count + channel.tracking.unreadCount;
      } else {
        // Public channel mentions are urgent
        return count + channel.tracking.mentionCount;
      }
    }, 0);
  }

  // Calculate unread count for starred channels (public channel unreads only)
  get starredChannelsUnreadCount() {
    return this.chatChannelsManager.starredChannels.reduce((count, channel) => {
      if (channel.isCategoryChannel) {
        return count + channel.tracking.unreadCount;
      }
      return count;
    }, 0);
  }

  <template>
    {{#if this.showUrgent}}
      <div class="c-unread-indicator -urgent">
        <div class="c-unread-indicator__number">
          {{this.urgentBadgeCount}}
        </div>
      </div>
    {{else if this.showUnread}}
      <div class="c-unread-indicator"></div>
    {{/if}}
  </template>
}
