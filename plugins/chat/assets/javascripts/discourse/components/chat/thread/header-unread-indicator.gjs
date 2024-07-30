import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

export default class ThreadHeaderUnreadIndicator extends Component {
  @service currentUser;

  unreadCountLabel = I18n.t("chat.unread_threads_count", {
    count: this.cappedUnreadCount,
  });

  get unreadCount() {
    return this.args.channel.threadsManager.unreadThreadCount;
  }

  get showUnreadIndicator() {
    return !this.currentUser.isInDoNotDisturb() && this.unreadCount > 0;
  }

  get cappedUnreadCount() {
    return this.unreadCount > 99 ? "99+" : this.unreadCount;
  }

  <template>
    {{#if this.showUnreadIndicator}}
      <div
        class="chat-thread-header-unread-indicator"
        title={{this.unreadCountLabel}}
      >
        <div
          class="chat-thread-header-unread-indicator__number"
        >{{this.cappedUnreadCount}}</div>
      </div>
    {{/if}}
  </template>
}
