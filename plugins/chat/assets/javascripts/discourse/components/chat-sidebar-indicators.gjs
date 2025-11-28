import Component from "@glimmer/component";
import UserStatusMessage from "discourse/components/user-status-message";
import icon from "discourse/helpers/d-icon";

/**
 * Displays unread indicators and user status for chat channels in the sidebar.
 *
 * @component ChatSidebarIndicators
 * @param {Object} @status - Channel status object containing unread counts and user status
 * @param {number} @status.unreadCount - Number of unread messages
 * @param {number} @status.unreadThreadsCount - Number of unread threads
 * @param {number} @status.mentionCount - Number of unread mentions
 * @param {number} @status.watchedThreadsUnreadCount - Number of unread watched threads
 * @param {boolean} @status.isDirectMessageChannel - Whether this is a DM channel
 * @param {Object} @status.userStatus - User status object for DM channels
 */
export default class ChatSidebarIndicators extends Component {
  /**
   * Determines if the channel has any unread content (messages or threads).
   *
   * @returns {boolean} True if there are unread messages or threads
   */
  get hasUnread() {
    return (
      this.args.status?.unreadCount > 0 ||
      this.args.status?.unreadThreadsCount > 0
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
      this.args.status?.mentionCount > 0 ||
      this.args.status?.watchedThreadsUnreadCount > 0;

    // For DMs, treat all unreads as urgent
    const hasUnreadDM =
      this.args.status?.isDirectMessageChannel &&
      this.args.status?.unreadCount > 0;

    if (hasUrgent || hasUnreadDM) {
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
