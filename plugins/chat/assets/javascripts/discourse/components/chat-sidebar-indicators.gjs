import Component from "@glimmer/component";
import UserStatusMessage from "discourse/components/user-status-message";
import icon from "discourse/helpers/d-icon";

/**
 * Displays unread indicators and user status for chat channels in the sidebar.
 *
 * @component ChatSidebarIndicators
 * @param {Object} @suffixArgs - Arguments object when used as @suffixComponent
 * @param {number} @suffixArgs.unreadCount - Number of unread messages
 * @param {number} @suffixArgs.unreadThreadsCount - Number of unread threads
 * @param {number} @suffixArgs.mentionCount - Number of unread mentions
 * @param {number} @suffixArgs.watchedThreadsUnreadCount - Number of unread watched threads
 * @param {boolean} @suffixArgs.isDirectMessageChannel - Whether this is a DM channel
 * @param {Object} @suffixArgs.userStatus - User status object for DM channels
 */
export default class ChatSidebarIndicators extends Component {
  /**
   * Determines if the channel has any unread content (messages, threads, mentions, or watched threads).
   *
   * @returns {boolean} True if there are any unreads that should show an indicator
   */
  get hasUnread() {
    return (
      this.args.suffixArgs?.unreadCount > 0 ||
      this.args.suffixArgs?.unreadThreadsCount > 0 ||
      this.args.suffixArgs?.mentionCount > 0 ||
      this.args.suffixArgs?.watchedThreadsUnreadCount > 0
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
      this.args.suffixArgs?.mentionCount > 0 ||
      this.args.suffixArgs?.watchedThreadsUnreadCount > 0;

    // For DMs, treat all unreads as urgent
    const hasUnreadDM =
      this.args.suffixArgs?.isDirectMessageChannel &&
      this.args.suffixArgs?.unreadCount > 0;

    if (hasUrgent || hasUnreadDM) {
      return "urgent";
    }
    return "unread";
  }

  <template>
    {{#if @suffixArgs.userStatus}}
      <UserStatusMessage @status={{@suffixArgs.userStatus}} />
    {{/if}}
    {{#if this.hasUnread}}
      <span
        class="sidebar-section-link-content-badge icon {{this.urgencyClass}}"
      >{{icon "circle"}}</span>
    {{/if}}
  </template>
}
