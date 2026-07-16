import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import optionalService from "discourse/lib/optional-service";

export default class EmbeddableChat extends Service {
  @service siteSettings;
  @service router;
  @service currentUser;
  @service capabilities;
  @optionalService chat;

  @tracked isMobileChatVisible = false;

  get userCanChat() {
    return this.chat?.userCanChat ?? false;
  }

  canRenderChatChannel(mobileViewAllowed = false) {
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

      if (withinPathsAllowed && this.chatChannelId) {
        return true;
      }
    }

    return false;
  }

  @action
  toggleChatVisibility() {
    this.isMobileChatVisible = !this.isMobileChatVisible;
  }

  @action
  closeChatVisibility() {
    this.isMobileChatVisible = false;
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

  get topicController() {
    return getOwner(this).lookup("controller:topic");
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
