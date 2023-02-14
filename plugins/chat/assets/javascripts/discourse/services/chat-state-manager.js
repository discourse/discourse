import Service, { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";
import KeyValueStore from "discourse/lib/key-value-store";
import Site from "discourse/models/site";

const PREFERRED_MODE_KEY = "preferred_mode";
const PREFERRED_MODE_STORE_NAMESPACE = "discourse_chat_";
const FULL_PAGE_CHAT = "FULL_PAGE_CHAT";
const DRAWER_CHAT = "DRAWER_CHAT";

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

  didOpenDrawer(URL = null) {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", true);

    if (URL) {
      this.storeChatURL(URL);
    }

    this.chat.updatePresence();
  }

  didCloseDrawer() {
    this.set("isDrawerActive", false);
    this.set("isDrawerExpanded", false);
    this.chat.updatePresence();
  }

  didExpandDrawer() {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", true);
    this.chat.updatePresence();
  }

  didCollapseDrawer() {
    this.set("isDrawerActive", true);
    this.set("isDrawerExpanded", false);
  }

  didToggleDrawer() {
    this.set("isDrawerExpanded", !this.isDrawerExpanded);
    this.set("isDrawerActive", true);
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

  storeAppURL(URL = null) {
    this._appURL = URL || this.router.currentURL;
  }

  storeChatURL(URL = null) {
    this._chatURL = URL || this.router.currentURL;
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
}
