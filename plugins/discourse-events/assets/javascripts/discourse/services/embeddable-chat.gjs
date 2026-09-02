import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import optionalService from "discourse/lib/optional-service";
import { isPastEventTimeframe } from "../models/discourse-post-event-event";

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

  get isPathAllowed() {
    const allowedPaths =
      this.siteSettings.livestream_embeddable_chat_allowed_paths
        .split("|")
        .map((path) => path.trim())
        .filter(Boolean);

    const currentURL = this.router.currentURL.split("?")[0];

    return allowedPaths.some((path) => {
      const normalized = path.endsWith("/") ? path.slice(0, -1) : path;
      return (
        currentURL === normalized || currentURL.startsWith(`${normalized}/`)
      );
    });
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

  get showLivestreamHeaderChatIcon() {
    return (
      this.isMobileViewport &&
      !!this.chatChannelId &&
      !this.hasActiveZoomLivestream
    );
  }

  get hasActiveZoomLivestream() {
    if (!this.siteSettings.livestream_zoom_enabled) {
      return false;
    }

    const event = this.topic?.postStream?.posts?.find(
      (post) => post.post_number === 1
    )?.event;

    return (
      !!event?.is_zoom_livestream &&
      !isPastEventTimeframe(event.all_day, event.starts_at, event.ends_at)
    );
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

  get useLivestreamLayout() {
    return (
      this.router.currentRouteName?.startsWith("topic.") &&
      this.topicHasLivestream &&
      !!this.chatChannelId &&
      !this.isChannelOpenInDrawer
    );
  }

  get isChatDocked() {
    return (
      this.useLivestreamLayout &&
      (this.canRenderChatChannel(false) || this.canRenderChatChannel(true))
    );
  }

  canRenderChatChannel(mobileViewAllowed = false) {
    if (
      this.isMobileViewport === mobileViewAllowed &&
      this.siteSettings.chat_enabled &&
      this.currentUser &&
      this.userCanChat
    ) {
      if (this.isPathAllowed && this.chatChannelId) {
        return !this.isChannelOpenInDrawer;
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
}
