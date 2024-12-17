import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { NotificationLevels } from "discourse/lib/notification-levels";
import ThreadNotificationsTracking from "discourse/plugins/chat/discourse/components/thread-notifications-tracking";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export default class ChatNavbarThreadTrackingDropdown extends Component {
  @service chatApi;

  @tracked persistedNotificationLevel = true;

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
      this.persistedNotificationLevel = true;
    } catch (error) {
      this.membership.notificationLevel = currentNotificationLevel;
      popupAjaxError(error);
    }
  }

  <template>
    <ThreadNotificationsTracking
      @levelId={{this.threadNotificationLevel}}
      @onChange={{this.updateThreadNotificationLevel}}
      class={{concatClass
        "c-navbar__thread-tracking-dropdown"
        (if this.persistedNotificationLevel "-persisted")
      }}
    />
  </template>
}
