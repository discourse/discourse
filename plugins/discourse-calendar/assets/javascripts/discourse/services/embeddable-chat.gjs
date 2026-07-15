import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import optionalService from "discourse/lib/optional-service";

export default class EmbeddableChat extends Service {
  @service siteSettings;
  @service router;
  @service currentUser;
  @service capabilities;
  @optionalService chat;
  @optionalService chatStateManager;

  @tracked isMobileChatVisible = false;

  get userCanChat() {
    return this.chat?.userCanChat ?? false;
  }

  get isChannelOpenInDrawer() {
    return (
      this.chatStateManager?.isDrawerActive &&
      this.chatStateManager?.isDrawerExpanded &&
      this.chat?.activeChannel?.id === this.chatChannelId
    );
  }

  canRenderChatChannel(topicController, mobileViewAllowed = false) {
    this.topicController = topicController;
    if (
      this.isMobileViewport === mobileViewAllowed &&
      this.siteSettings.chat_enabled &&
      this.currentUser &&
      this.userCanChat
    ) {
      const allowedPaths =
        this.siteSettings.livestream_embeddable_chat_allowed_paths.split("|");
      const withinPathsAllowed = allowedPaths.some(
        (path) =>
          this.router.currentURL.includes(path) ||
          this.router.currentURL.startsWith(path)
      );

      if (withinPathsAllowed && this.topicController?.model?.chat_channel_id) {
        return !this.isChannelOpenInDrawer;
      }
    }

    return false;
  }

  @action
  toggleChatVisibility() {
    this.isMobileChatVisible = !this.isMobileChatVisible;
  }

  get isMobileModal() {
    return (
      this.siteSettings.livestream_enable_modal_chat_on_mobile &&
      this.isMobileViewport
    );
  }

  get isMobileViewport() {
    return !this.capabilities.viewport.lg;
  }

  get topic() {
    return this.topicController?.model;
  }

  get chatChannelId() {
    return this.topic?.chat_channel_id;
  }

  get topicHasLivestream() {
    return this.topic?.has_livestream;
  }
}
