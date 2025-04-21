import Service, { service } from "@ember/service";

export default class ChatGuardian extends Service {
  @service currentUser;
  @service siteSettings;

  canEditChatChannel() {
    return this.canUseChat() && this.currentUser.staff;
  }

  canArchiveChannel(channel) {
    return (
      this.canEditChatChannel() &&
      this.siteSettings.chat_allow_archiving_channels &&
      !channel.isArchived &&
      !channel.isReadOnly
    );
  }

  canUseChat() {
    return this.currentUser?.has_chat_enabled && this.siteSettings.chat_enabled;
  }
}
