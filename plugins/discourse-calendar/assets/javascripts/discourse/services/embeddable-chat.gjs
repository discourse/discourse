import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Chat from "discourse/plugins/chat/discourse/services/chat";

export const LIVESTREAM_TAG_NAME = "livestream";

export default class EmbeddableChat extends Chat {
  @service siteSettings;
  @service router;
  @service currentUser;
  @service capabilities;

  @tracked isMobileChatVisible = false;

  canRenderChatChannel(topicController, mobileViewAllowed = false) {
    this.topicController = topicController;
    if (
      this.siteSettings.livestream_enabled &&
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
        return true;
      }
    }

    return false;
  }

  @action
  toggleChatVisibility() {
    this.isMobileChatVisible = !this.isMobileChatVisible;
  }

  topicHasLivestreamTag(topic) {
    return (
      // TODO(https://github.com/discourse/discourse/pull/36678): The string check can be
      // removed using .discourse-compatibility once the PR is merged.
      topic?.tags?.some?.((tag) => {
        const tagName = typeof tag === "string" ? tag : tag.name;
        return tagName === LIVESTREAM_TAG_NAME;
      }) || false
    );
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

  get chatChannelId() {
    return this.topicController?.model?.chat_channel_id;
  }
}
