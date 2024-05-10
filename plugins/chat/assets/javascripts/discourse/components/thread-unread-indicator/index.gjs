import Component from "@glimmer/component";

export default class ChatThreadUnreadIndicator extends Component {
  get unreadCount() {
    return this.args.thread.tracking.unreadCount;
  }

  get showUnreadIndicator() {
    return this.unreadCount > 0;
  }

  get unreadCountLabel() {
    return this.unreadCount > 99 ? "99+" : this.unreadCount;
  }

  <template>
    {{#if this.showUnreadIndicator}}
      <span class="chat-thread-list-item-unread-indicator">
        <span class="chat-thread-list-item-unread-indicator__number">
          {{this.unreadCountLabel}}
        </span>
      </span>
    {{/if}}
  </template>
}
