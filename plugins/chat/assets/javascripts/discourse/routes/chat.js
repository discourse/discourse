import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import { defaultHomepage } from "discourse/lib/utilities";
import Session from "discourse/models/session";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";
import {
  CHAT_PANEL,
  initSidebarState,
} from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

export default class ChatRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service chatStateManager;
  @service chatDrawerRouter;
  @service currentUser;

  titleToken() {
    return i18n("chat.title_capitalized");
  }

  beforeModel(transition) {
    if (!this.chat.userCanChat) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }

    // Check if user prefers drawer mode and the route can be handled in drawer
    const isDrawerPreferred = this.chatStateManager.isDrawerPreferred;
    const canHandleInDrawer = this.chatDrawerRouter.canHandleRoute(
      transition.to
    );
    const fullPageReload = !transition.from;
    const requiresRefresh = Session.currentProp("requiresRefresh");

    // Don't intercept direct loads unless requiresRefresh is forcing a reload
    // This preserves the original behavior: if someone directly types /chat in
    // the address bar, show them full page chat (they explicitly chose it).
    // But if requiresRefresh caused a reload mid-session, respect drawer preference.
    if (
      isDrawerPreferred &&
      canHandleInDrawer &&
      (!fullPageReload || requiresRefresh)
    ) {
      transition.abort();

      let url = transition.intent.url;

      if (transition.targetName.startsWith("chat.channel")) {
        url ??= this.router.urlFor(
          transition.targetName,
          ...transition.intent.contexts
        );
      } else {
        url ??= this.router.urlFor(transition.targetName);
      }

      // If this is a full page reload (no transition.from), we need to
      // navigate to a non-chat page first before opening the drawer
      if (fullPageReload) {
        const appURL =
          this.chatStateManager.lastKnownAppURL ||
          `discovery.${defaultHomepage()}`;
        return this.router.transitionTo(appURL).then(() => {
          this.appEvents.trigger("chat:open-url", url);
        });
      }

      // Normal SPA navigation - just open the drawer
      this.appEvents.trigger("chat:open-url", url);
      return;
    }

    // Full page mode - close any open drawer
    this.appEvents.trigger("chat:toggle-close");
  }

  activate() {
    withPluginApi((api) => {
      api.setSidebarPanel(CHAT_PANEL);

      const chatSeparateSidebarMode = getUserChatSeparateSidebarMode(
        this.currentUser
      );

      if (chatSeparateSidebarMode.never) {
        api.setCombinedSidebarMode();
        api.hideSidebarSwitchPanelButtons();
      } else {
        api.setSeparatedSidebarMode();
      }
    });

    this.chatStateManager.storeAppURL();
    this.chat.updatePresence();
  }

  deactivate(transition) {
    withPluginApi((api) => {
      initSidebarState(api, this.currentUser);
    });

    if (transition) {
      let url = this.router.urlFor(transition.from.name);

      if (this.router.rootURL !== "/") {
        url = url.replace(new RegExp(`^${this.router.rootURL}`), "/");
      }

      this.chatStateManager.storeChatURL(url);
    }

    this.chat.activeChannel = null;
    this.chat.updatePresence();
  }
}
