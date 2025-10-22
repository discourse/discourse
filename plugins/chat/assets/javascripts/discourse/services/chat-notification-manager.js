import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  alertChannel,
  onNotification as onDesktopNotification,
} from "discourse/lib/desktop-notifications";
import { isTesting } from "discourse/lib/environment";

export default class ChatNotificationManager extends Service {
  @service capabilities;
  @service chat;
  @service currentUser;
  @service appEvents;

  willDestroy() {
    super.willDestroy(...arguments);

    if (!this.#shouldRun) {
      return;
    }

    this.messageBus.unsubscribe(this.messageBusChannel, this.onMessage);
  }

  start() {
    if (!this.#shouldRun) {
      return;
    }

    this.messageBus.subscribe(this.messageBusChannel, this.onMessage);
  }

  get messageBusChannel() {
    return `/chat${alertChannel(this.currentUser)}`;
  }

  @bind
  async onMessage(data) {
    // if the user is currently focused on this tab and channel,
    // we don't want to show a desktop notification
    if (
      this.session.hasFocus &&
      data.channel_id === this.chat.activeChannel?.id
    ) {
      return;
    }

    return onDesktopNotification(
      data,
      this.siteSettings,
      this.currentUser,
      this.appEvents
    );
  }

  get #shouldRun() {
    return (
      !this.capabilities.isMobileDevice && this.chat.userCanChat && !isTesting()
    );
  }
}
