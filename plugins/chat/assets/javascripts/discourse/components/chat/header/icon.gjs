import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import getURL from "discourse-common/lib/get-url";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";
import ChatHeaderIconUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/header/icon/unread-indicator";
import icon from "discourse-common/helpers/d-icon";
import concatClass from "discourse/helpers/concat-class";
import I18n from "I18n";

export default class ChatHeaderIcon extends Component {
  <template>
    <a
      href={{this.href}}
      tabindex="0"
      class={{concatClass "icon" "btn-flat" (if this.isActive "active")}}
      title={{this.title}}
    >
      {{~icon this.icon~}}
      {{#if this.showUnreadIndicator}}
        <ChatHeaderIconUnreadIndicator
          @urgentCount={{@urgentCount}}
          @unreadCount={{@unreadCount}}
          @indicatorPreference={{@indicatorPreference}}
        />
      {{/if}}
    </a>
  </template>

  @service currentUser;
  @service site;
  @service chatStateManager;
  @service router;

  get showUnreadIndicator() {
    if (this.chatStateManager.isFullPageActive && this.site.desktopView) {
      return false;
    }
    return !this.currentUserInDnD;
  }

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
      return I18n.t("sidebar.panels.forum.label");
    }

    return I18n.t("chat.title_capitalized");
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
