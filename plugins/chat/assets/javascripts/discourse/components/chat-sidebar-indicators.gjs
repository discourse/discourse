import Component from "@glimmer/component";
import UserStatusMessage from "discourse/components/user-status-message";
import icon from "discourse/helpers/d-icon";

export default class ChatSidebarIndicators extends Component {
  get hasUnread() {
    return (
      this.args.status?.unreadCount > 0 ||
      this.args.status?.unreadThreadsCount > 0
    );
  }

  get urgencyClass() {
    if (
      this.args.status?.mentionCount > 0 ||
      this.args.status?.watchedThreadsUnreadCount > 0
    ) {
      return "urgent";
    }
    return "unread";
  }

  <template>
    {{#if @status.userStatus}}
      <UserStatusMessage @status={{@status.userStatus}} />
    {{/if}}
    {{#if this.hasUnread}}
      <span
        class="sidebar-section-link-content-badge icon {{this.urgencyClass}}"
      >{{icon "circle"}}</span>
    {{/if}}
  </template>
}
