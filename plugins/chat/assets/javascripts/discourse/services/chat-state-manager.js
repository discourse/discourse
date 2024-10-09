import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";
import { withPluginApi } from "discourse/lib/plugin-api";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { defaultHomepage } from "discourse/lib/utilities";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";
import { CHAT_PANEL } from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

const PREFERRED_MODE_KEY = "preferred_mode";
const PREFERRED_MODE_STORE_NAMESPACE = "discourse_chat_";
const FULL_PAGE_CHAT = "FULL_PAGE_CHAT";
const DRAWER_CHAT = "DRAWER_CHAT";

let chatDrawerStateCallbacks = [];

export function addChatDrawerStateCallback(callback) {
  chatDrawerStateCallbacks.push(callback);
}

export function resetChatDrawerStateCallbacks() {
  chatDrawerStateCallbacks = [];
}

export default class ChatStateManager extends Service {
  @service chat;
  @service chatHistory;
  @service router;
  @service site;
  @service chatDrawerRouter;

  @tracked isSidePanelExpanded = false;
  @tracked isDrawerExpanded = false;
  @tracked isDrawerActive = false;
  @tracked hasPreloadedChannels = false;

  @tracked _chatURL = null;
  @tracked _appURL = null;

  _store = new KeyValueStore(PREFERRED_MODE_STORE_NAMESPACE);

  reset() {
    this._store.remove(PREFERRED_MODE_KEY);
    this._chatURL = null;
    this._appURL = null;
  }

  prefersFullPage() {
    this._store.setObject({ key: PREFERRED_MODE_KEY, value: FULL_PAGE_CHAT });
  }

  prefersDrawer() {
    this._store.setObject({ key: PREFERRED_MODE_KEY, value: DRAWER_CHAT });
  }

  openSidePanel() {
    this.isSidePanelExpanded = true;
  }

  closeSidePanel() {
    this.isSidePanelExpanded = false;
  }

  didOpenDrawer(url = null) {
    withPluginApi("1.8.0", (api) => {
      if (
        api.getSidebarPanel()?.key === MAIN_PANEL ||
        api.getSidebarPanel()?.key === CHAT_PANEL
      ) {
        if (getUserChatSeparateSidebarMode(this.currentUser).always) {
          api.setSeparatedSidebarMode();
          api.hideSidebarSwitchPanelButtons();
        } else {
          api.setCombinedSidebarMode();
        }
      }
    });

    this.isDrawerActive = true;
    this.isDrawerExpanded = true;

    if (url) {
      this.storeChatURL(url);
    }

    this.chat.updatePresence();
    this.#publishStateChange();
  }

  didCloseDrawer() {
    withPluginApi("1.8.0", (api) => {
      if (
        api.getSidebarPanel()?.key === MAIN_PANEL ||
        api.getSidebarPanel()?.key === CHAT_PANEL
      ) {
        const chatSeparateSidebarMode = getUserChatSeparateSidebarMode(
          this.currentUser
        );

        api.setSidebarPanel(MAIN_PANEL);

        if (chatSeparateSidebarMode.fullscreen) {
          api.setCombinedSidebarMode();
          api.showSidebarSwitchPanelButtons();
        } else if (chatSeparateSidebarMode.always) {
          api.setSeparatedSidebarMode();
          api.showSidebarSwitchPanelButtons();
        } else {
          api.setCombinedSidebarMode();
          api.hideSidebarSwitchPanelButtons();
        }
      }
    });

    this.chatDrawerRouter.currentRouteName = null;
    this.isDrawerActive = false;
    this.isDrawerExpanded = false;
    this.chat.updatePresence();
    this.#publishStateChange();
  }

  didExpandDrawer() {
    this.isDrawerActive = true;
    this.isDrawerExpanded = true;
    this.chat.updatePresence();
  }

  didCollapseDrawer() {
    this.isDrawerActive = true;
    this.isDrawerExpanded = false;
    this.#publishStateChange();
  }

  didToggleDrawer() {
    this.isDrawerExpanded = !this.isDrawerExpanded;
    this.isDrawerActive = true;
    this.#publishStateChange();
  }

  get isFullPagePreferred() {
    return !!(
      this.site.mobileView ||
      this._store.getObject(PREFERRED_MODE_KEY) === FULL_PAGE_CHAT
    );
  }

  get isDrawerPreferred() {
    return !!(
      !this.isFullPagePreferred ||
      (this.site.desktopView &&
        (!this._store.getObject(PREFERRED_MODE_KEY) ||
          this._store.getObject(PREFERRED_MODE_KEY) === DRAWER_CHAT))
    );
  }

  get isFullPageActive() {
    return this.router.currentRouteName?.startsWith("chat");
  }

  get isActive() {
    return this.isFullPageActive || this.isDrawerActive;
  }

  storeAppURL(url = null) {
    if (url) {
      this._appURL = url;
    } else if (this.router.currentURL?.startsWith("/chat")) {
      this._appURL = "/";
    } else {
      this._appURL = this.router.currentURL;
    }
  }

  storeChatURL(url) {
    this._chatURL = url;
  }

  get lastKnownAppURL() {
    const url = this._appURL;

    if (url && url !== "/") {
      return url;
    }

    return this.router.urlFor(`discovery.${defaultHomepage()}`);
  }

  get lastKnownChatURL() {
    return this._chatURL || "/chat";
  }

  #publishStateChange() {
    const state = {
      isDrawerActive: this.isDrawerActive,
      isDrawerExpanded: this.isDrawerExpanded,
    };

    chatDrawerStateCallbacks.forEach((callback) => callback(state));
  }
}
