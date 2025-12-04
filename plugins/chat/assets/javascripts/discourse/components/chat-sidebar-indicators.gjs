import Component from "@glimmer/component";
import UserStatusMessage from "discourse/components/user-status-message";
import icon from "discourse/helpers/d-icon";

/**
 * Displays unread indicators and user status for chat channels in the sidebar.
 *
 * @component ChatSidebarIndicators
 * @param {Object} @args - Arguments object when used as @suffixComponent
 * @param {number} @args.unreadCount - Number of unread messages
 * @param {number} @args.unreadThreadsCount - Number of unread threads
 * @param {number} @args.mentionCount - Number of unread mentions
 * @param {number} @args.watchedThreadsUnreadCount - Number of unread watched threads
 * @param {boolean} @args.isDirectMessageChannel - Whether this is a DM channel
 * @param {Object} @args.userStatus - User status object for DM channels
 */
export default class ChatSidebarIndicators extends Component {
  /**
   * Determines if the channel has any unread content (messages, threads, mentions, or watched threads).
   *
   * @returns {boolean} True if there are any unreads that should show an indicator
   */
  get hasUnread() {
    return (
      this.args.status?.unreadCount > 0 ||
      this.args.status?.unreadThreadsCount > 0 ||
      this.args.status?.mentionCount > 0 ||
      this.args.status?.watchedThreadsUnreadCount > 0
    );
  }

  /**
   * Determines the urgency class for the unread indicator.
   * Returns "urgent" for mentions, watched threads, or any DM unreads.
   * Returns "unread" for regular unread messages.
   *
   * @returns {string} CSS class name - either "urgent" or "unread"
   */
  get urgencyClass() {
    const hasUrgent =
      this.args.args?.mentionCount > 0 ||
      this.args.args?.watchedThreadsUnreadCount > 0;

    // For DMs, treat all unreads as urgent
    const hasUnreadDM =
      this.args.args?.isDirectMessageChannel && this.args.args?.unreadCount > 0;

    if (hasUrgent || hasUnreadDM) {
      return "urgent";
    }
    return "unread";
  }

  <template>
    {{#if @args.userStatus}}
      <UserStatusMessage @status={{@args.userStatus}} />
    {{/if}}
    {{#if this.hasUnread}}
      <span
        class="sidebar-section-link-content-badge icon {{this.urgencyClass}}"
      >{{icon "circle"}}</span>
    {{/if}}
  </template>
}
