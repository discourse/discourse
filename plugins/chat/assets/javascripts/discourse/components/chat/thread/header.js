import Component from "@glimmer/component";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import { tracked } from "@glimmer/tracking";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service chatApi;
  @service router;
  @service chatStateManager;
  @service chatHistory;
  @service site;

  @tracked persistedNotificationLevel = true;

  get backLink() {
    if (
      this.chatHistory.previousRoute?.name === "chat.channel.index" &&
      this.site.mobileView
    ) {
      return {
        route: "chat.channel.index",
        models: this.args.channel.routeModels,
      };
    } else {
      return {
        route: "chat.channel.threads",
        models: [],
      };
    }
  }

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
  updateThreadNotificationLevel(newNotificationLevel) {
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

    this.chatApi
      .updateCurrentUserThreadNotificationsSettings(
        this.args.thread.channel.id,
        this.args.thread.id,
        { notificationLevel: newNotificationLevel }
      )
      .then((response) => {
        this.membership.last_read_message_id =
          response.membership.last_read_message_id;

        this.persistedNotificationLevel = true;
      })
      .catch((err) => {
        this.membership.notificationLevel = currentNotificationLevel;
        popupAjaxError(err);
      });
  }
}
