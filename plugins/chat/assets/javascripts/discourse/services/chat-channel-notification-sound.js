import Service, { service } from "@ember/service";
import { canUserReceiveNotifications } from "discourse/lib/desktop-notifications";

export default class ChatChannelNotificationSound extends Service {
  @service chat;
  @service chatAudioManager;
  @service currentUser;
  @service site;

  async play(channel) {
    if (!canUserReceiveNotifications(this.currentUser)) {
      return false;
    }

    if (channel.isCategoryChannel) {
      return false;
    }

    if (channel.chatable.group) {
      return false;
    }

    if (!this.currentUser.chat_sound) {
      return false;
    }

    if (this.site.mobileView) {
      return false;
    }

    const membership = channel.currentUserMembership;
    if (!membership.following) {
      return false;
    }

    if (membership.desktopNotificationLevel !== "always") {
      return false;
    }

    if (membership.muted) {
      return false;
    }

    if (this.chat.activeChannel === channel) {
      return false;
    }

    await this.chatAudioManager.play(this.currentUser.chat_sound);

    return true;
  }
}
