import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import ChatHeaderIconUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/header/icon/unread-indicator";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";

export default class ChatHeaderIcon extends Component {
  @service currentUser;
  @service site;
  @service chatStateManager;

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
      this.site.desktopView
    ) {
      return i18n("chat.exit");
    }

    return i18n("chat.title_capitalized");
  }

  get icon() {
    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never &&
      this.site.desktopView
    ) {
      return "shuffle";
    }

    return "d-chat";
  }

  get href() {
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

  <template>
    {{#unless (and this.site.mobileView this.isActive)}}
      <li class="header-dropdown-toggle chat-header-icon">
        <DButton
          @href={{this.href}}
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
        </DButton>
      </li>
    {{/unless}}
  </template>
}
