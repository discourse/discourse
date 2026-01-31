import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ChatHeaderIconUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/header/icon/unread-indicator";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";

export default class ChatHeaderIcon extends Component {
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

  @action
  openChat() {
    // If exiting full page chat, just navigate to app URL
    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never
    ) {
      this.router.transitionTo(this.chatStateManager.lastKnownAppURL || "/");
      return;
    }

    // If drawer is already active, navigate to chat (will toggle/refresh)
    if (this.chatStateManager.isDrawerActive) {
      this.router.transitionTo("/chat");
      return;
    }

    // Opening chat: explicitly set drawer preference before navigating
    // This ensures the route's beforeModel respects drawer mode even on
    // full page loads (e.g., after browser refresh)
    if (this.chatStateManager.isDrawerPreferred) {
      this.chatStateManager.prefersDrawer();
    }
    this.router.transitionTo(this.chatStateManager.lastKnownChatURL || "/chat");
  }

  <template>
    {{#unless (and this.site.mobileView this.isActive)}}
      <li class="header-dropdown-toggle chat-header-icon">
        <DButton
          @action={{this.openChat}}
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
              @class="c-unread-indicator__number"
            />
          {{/if}}
        </DButton>
      </li>
    {{/unless}}
  </template>
}
