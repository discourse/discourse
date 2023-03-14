import Service, { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import KeyValueStore from "discourse/lib/key-value-store";
import Site from "discourse/models/site";

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
  @service router;
  isDrawerExpanded = false;
  isDrawerActive = false;
  isSidePanelExpanded = false;
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
    this.set("isSidePanelExpanded", true);
  }

  closeSidePanel() {
    this.set("isSidePanelExpanded", false);
  }

  didOpenDrawer(url = null) {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", true);

    if (url) {
      this.storeChatURL(url);
    }

    this.chat.updatePresence();
    this.#publishStateChange();
  }

  didCloseDrawer() {
    this.set("isDrawerActive", false);
    this.set("isDrawerExpanded", false);
    this.chat.updatePresence();
    this.#publishStateChange();
  }

  didExpandDrawer() {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", true);
    this.chat.updatePresence();
  }

  didCollapseDrawer() {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", false);
    this.#publishStateChange();
  }

  didToggleDrawer() {
    this.set("isDrawerExpanded", !this.isDrawerExpanded);
    this.set("isDrawerActive", true);
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

  storeChatURL(url = null) {
    this._chatURL = url || this.router.currentURL;
  }

  get lastKnownAppURL() {
    let url = this._appURL;
    if (!url || url === "/") {
      url = this.router.urlFor(`discovery.${defaultHomepage()}`);
    }

    return url;
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
