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
  @service composer;
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
      this.chatStateManager.isDrawerActive ||
      this.chatStateManager.isSidePanelActive
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

  get targetUrl() {
    if (
      this.chatStateManager.isFullPageActive &&
      !this.chatSeparateSidebarMode.never
    ) {
      return this.chatStateManager.lastKnownAppURL || "/";
    }

    if (
      this.chatStateManager.isDrawerActive ||
      this.chatStateManager.isSidePanelActive
    ) {
      return "/chat";
    }

    return this.chatStateManager.lastKnownChatURL || "/chat";
  }

  get href() {
    return getURL(this.targetUrl);
  }

  @action
  openChat() {
    // In side panel mode, shrink the composer to make room for the panel
    if (
      (this.chatStateManager.isSidePanelPreferred ||
        this.chatStateManager.isSidePanelActive) &&
      this.composer.isOpen
    ) {
      this.composer.shrink();

      // If side panel is already open, shrinking the composer is enough
      if (this.chatStateManager.isSidePanelActive) {
        return;
      }
    }

    // Opening chat: explicitly set drawer/side-panel preference before navigating
    // This ensures the route's beforeModel respects the mode even on
    // full page loads (e.g., after browser refresh)
    if (this.chatStateManager.isDrawerPreferred) {
      this.chatStateManager.prefersDrawer();
    } else if (this.chatStateManager.isSidePanelPreferred) {
      this.chatStateManager.prefersSidePanel();
    }
    this.router.transitionTo(this.targetUrl);
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
            />
          {{/if}}
        </DButton>
      </li>
    {{/unless}}
  </template>
}
