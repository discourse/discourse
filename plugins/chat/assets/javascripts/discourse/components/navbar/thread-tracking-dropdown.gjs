import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { NotificationLevels } from "discourse/lib/notification-levels";
import ThreadTrackingDropdown from "discourse/plugins/chat/discourse/components/chat-thread-tracking-dropdown";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export default class ChatNavbarThreadTrackingDropdown extends Component {
  @service chatApi;

  get threadNotificationLevel() {
    return this.membership?.notificationLevel || NotificationLevels.REGULAR;
  }

  get membership() {
    return this.args.thread.currentUserMembership;
  }

  @action
  async updateThreadNotificationLevel(newNotificationLevel) {
    this.persistedNotificationLevel = false;

    let currentNotificationLevel;

    if (this.membership) {
      currentNotificationLevel = this.membership.notificationLevel;
      this.membership.notificationLevel = newNotificationLevel;
    } else {
      this.args.thread.currentUserMembership = UserChatThreadMembership.create({
        notification_level: newNotificationLevel,
        last_read_message_id: null,
      });
    }

    try {
      const response =
        await this.chatApi.updateCurrentUserThreadNotificationsSettings(
          this.args.thread.channel.id,
          this.args.thread.id,
          { notificationLevel: newNotificationLevel }
        );
      this.membership.last_read_message_id =
        response.membership.last_read_message_id;
    } catch (error) {
      this.membership.notificationLevel = currentNotificationLevel;
      popupAjaxError(error);
    }
  }

  <template>
    <ThreadTrackingDropdown
      @value={{this.threadNotificationLevel}}
      @onChange={{this.updateThreadNotificationLevel}}
      @class="c-navbar__thread-tracking-dropdown"
    />
  </template>
}
