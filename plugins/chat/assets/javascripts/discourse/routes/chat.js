import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import { defaultHomepage } from "discourse/lib/utilities";
import { scrollTop } from "discourse/mixins/scroll-top";
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

    if (
      transition.from && // don't intercept when directly loading chat
      this.chatStateManager.isDrawerPreferred &&
      this.chatDrawerRouter.routeNames.includes(transition.targetName)
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

      this.appEvents.trigger("chat:open-url", url);

      return;
    }

    this.appEvents.trigger("chat:toggle-close");
  }

  activate() {
    withPluginApi("1.8.0", (api) => {
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

    schedule("afterRender", () => {
      document.body.classList.add("has-full-page-chat");
      document.documentElement.classList.add("has-full-page-chat");
      scrollTop();
    });
  }

  deactivate(transition) {
    withPluginApi("1.8.0", (api) => {
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

    schedule("afterRender", () => {
      document.body.classList.remove("has-full-page-chat");
      document.documentElement.classList.remove("has-full-page-chat");
    });
  }
}
