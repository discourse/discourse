import Component from "@glimmer/component";

const MAX_UNREAD_COUNT = 99;

export default class ChatThreadUnreadIndicator extends Component {
  get unreadCount() {
    return this.args.thread.tracking.unreadCount;
  }

  get urgentCount() {
    return (
      this.args.thread.tracking.mentionCount +
      this.args.thread.tracking.watchedThreadsUnreadCount
    );
  }

  get showUnreadIndicator() {
    return this.unreadCount > 0 || this.urgentCount > 0;
  }

  get unreadCountLabel() {
    const count = this.urgentCount > 0 ? this.urgentCount : this.unreadCount;
    return count > MAX_UNREAD_COUNT ? `${MAX_UNREAD_COUNT}+` : count;
  }

  get isUrgent() {
    return this.urgentCount > 0 ? "-urgent" : "";
  }

  <template>
    {{#if this.showUnreadIndicator}}
      <span class="chat-thread-list-item-unread-indicator {{this.isUrgent}}">
        <span class="chat-thread-list-item-unread-indicator__number">
          {{this.unreadCountLabel}}
        </span>
      </span>
    {{/if}}
  </template>
}
