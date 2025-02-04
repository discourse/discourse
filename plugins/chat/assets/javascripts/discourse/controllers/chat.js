import Controller from "@ember/controller";
import { service } from "@ember/service";
import { FOOTER_NAV_ROUTES } from "discourse/plugins/chat/discourse/lib/chat-constants";

export default class ChatController extends Controller {
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;
  @service siteSettings;
  @service router;

  get shouldUseChatSidebar() {
    if (this.site.mobileView) {
      return false;
    }

    if (this.shouldUseCoreSidebar) {
      return false;
    }

    return true;
  }

  get publicMessageChannelsEmpty() {
    return (
      this.chatChannelsManager.publicMessageChannels?.length === 0 &&
      this.chatStateManager.hasPreloadedChannels
    );
  }

  get shouldUseCoreSidebar() {
    return this.siteSettings.navigation_menu === "sidebar";
  }

  get enabledRouteCount() {
    return [
      this.siteSettings.chat_threads_enabled,
      this.chat.userCanAccessDirectMessages,
      this.siteSettings.enable_public_channels,
    ].filter(Boolean).length;
  }

  get shouldUseChatFooter() {
    return (
      FOOTER_NAV_ROUTES.includes(this.router.currentRouteName) &&
      this.enabledRouteCount > 1
    );
  }

  get mainOutletModifierClasses() {
    let modifierClasses = [];

    if (this.chatStateManager.isSidePanelExpanded) {
      modifierClasses.push("has-side-panel-expanded");
    }

    if (
      !this.router.currentRouteName.startsWith("chat.channel.info") &&
      !this.router.currentRouteName.startsWith("chat.browse")
    ) {
      modifierClasses.push("chat-view");
    }

    return modifierClasses.join(" ");
  }
}
