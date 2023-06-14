import Component from "@glimmer/component";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service chatApi;
  @service router;

  get label() {
    return this.args.thread.escapedTitle;
  }

  get canChangeThreadSettings() {
    if (!this.args.thread) {
      return false;
    }

    return (
      this.currentUser.staff ||
      this.currentUser.id === this.args.thread.originalMessage.user.id
    );
  }

  get threadNotificationLevel() {
    return this.membership?.notificationLevel || NotificationLevels.REGULAR;
  }

  get membership() {
    return this.args.thread.currentUserMembership;
  }

  @action
  openThreadSettings() {
    const controller = showModal("chat-thread-settings-modal");
    controller.set("thread", this.args.thread);
  }

  @action
  updateThreadNotificationLevel(val) {
    let originalVal;

    if (this.membership) {
      originalVal = this.membership.notificationLevel;
      this.membership.notificationLevel = val;
    } else {
      this.args.thread.currentUserMembership = UserChatThreadMembership.create({
        notification_level: val,
        last_read_message_id: null,
      });
    }

    this.chatApi
      .updateCurrentUserThreadNotificationsSettings(
        this.args.thread.channel.id,
        this.args.thread.id,
        { notificationLevel: val }
      )
      .then((response) => {
        this.membership.last_read_message_id =
          response.membership.last_read_message_id;
      })
      .catch((err) => {
        if (this.membership && originalVal) {
          this.membership.notificationLevel = originalVal;
        }
        popupAjaxError(err);
      });
  }
}
