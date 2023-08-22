import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import getURL from "discourse-common/lib/get-url";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";
export default class ChatHeaderIcon extends Component {
  @service currentUser;
  @service site;
  @service chatStateManager;
  @service router;

  get currentUserInDnD() {
    return this.args.currentUserInDnD || this.currentUser.isInDoNotDisturb();
  }

  get chatSeparateSidebarMode() {
    return getUserChatSeparateSidebarMode(this.currentUser);
  }

  get isActive() {
    return (
      this.args.isActive ||
      this.chatStateManager.isFullPageActive ||
      this.chatStateManager.isDrawerActive
    );
  }

  get title() {
    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never &&
      !this.site.mobileView
    ) {
      return "sidebar.panels.forum.label";
    }

    return "chat.title_capitalized";
  }

  get icon() {
    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never &&
      !this.site.mobileView
    ) {
      return "random";
    }

    return "d-chat";
  }

  get href() {
    if (this.site.mobileView && this.chatStateManager.isFullPageActive) {
      return getURL("/chat");
    }

    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never
    ) {
      return getURL(this.chatStateManager.lastKnownAppURL || "/");
    }

    if (this.chatStateManager.isDrawerActive) {
      return getURL("/chat");
    }

    return getURL(this.chatStateManager.lastKnownChatURL || "/chat");
  }
}
