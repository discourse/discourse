import Service, { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import KeyValueStore from "discourse/lib/key-value-store";
import Site from "discourse/models/site";
import getURL from "discourse-common/lib/get-url";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";
import { withPluginApi } from "discourse/lib/plugin-api";

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

  @tracked isSidePanelExpanded = false;
  @tracked isDrawerExpanded = false;
  @tracked isDrawerActive = false;

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
      if (getUserChatSeparateSidebarMode(this.currentUser).always) {
        api.setSidebarPanel("main");
        api.setSeparatedSidebarMode();
        api.hideSidebarSwitchPanelButtons();
      } else {
        api.setCombinedSidebarMode();
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
      api.setSidebarPanel("main");

      const chatSeparateSidebarMode = getUserChatSeparateSidebarMode(
        this.currentUser
      );
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
    });

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
      Site.currentProp("mobileView") ||
      this._store.getObject(PREFERRED_MODE_KEY) === FULL_PAGE_CHAT
    );
  }

  get isDrawerPreferred() {
    return !!(
      !this.isFullPagePreferred ||
      (!Site.currentProp("mobileView") &&
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
    let url = this._appURL;
    if (!url || url === "/") {
      url = this.router.urlFor(`discovery.${defaultHomepage()}`);
    }

    return getURL(url);
  }

  get lastKnownChatURL() {
    return getURL(this._chatURL || "/chat");
  }

  #publishStateChange() {
    const state = {
      isDrawerActive: this.isDrawerActive,
      isDrawerExpanded: this.isDrawerExpanded,
    };

    chatDrawerStateCallbacks.forEach((callback) => callback(state));
  }
}
