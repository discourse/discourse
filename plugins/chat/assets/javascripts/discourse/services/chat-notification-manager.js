import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  alertChannel,
  onNotification as onDesktopNotification,
} from "discourse/lib/desktop-notifications";
import { isTesting } from "discourse/lib/environment";
import { claimChatAlert } from "discourse/plugins/chat/discourse/lib/chat-alert-dedup";

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
    // we don't want to show a desktop notification; claim the alert so
    // a backgrounded tab catching up later doesn't replay its sound
    if (
      this.session.hasFocus &&
      data.channel_id === this.chat.activeChannel?.id
    ) {
      // hasFocus tracks visibility, not focus, and starts out true — a tab
      // that has never been shown must not claim the alert
      if (!document.hidden) {
        claimChatAlert(data.chat_message_id);
      }
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
