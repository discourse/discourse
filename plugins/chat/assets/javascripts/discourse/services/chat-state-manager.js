import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import getURL, { withoutPrefix } from "discourse/lib/get-url";
import { discoveryHomepageRoute } from "discourse/lib/homepage-router-overrides";
import KeyValueStore from "discourse/lib/key-value-store";
import { withPluginApi } from "discourse/lib/plugin-api";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
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
  @service currentUser;
  @service chatChannelsManager;
  @service pageShell;
  @service router;
  @service sessionStore;
  @service site;
  @service chatDrawerRouter;

  @tracked isSidePanelExpanded = false;
  @tracked isDrawerInContext = false;
  @tracked contextDrawerSlot = null;
  @tracked hasPreloadedChannels = false;

  /**
   * Where a chat page renders its navbar when the header stands in for it,
   * as it does alongside the mobile tab bar.
   */
  @tracked headerNavbarSlot = null;

  #contextChatURL = tracked(null);
  #drawerActive = tracked(false);
  #drawerExpanded = tracked(false);

  @tracked _chatURL = null;

  @tracked _appURL = null;
  _store = new KeyValueStore(PREFERRED_MODE_STORE_NAMESPACE);

  constructor() {
    super(...arguments);
    if (this.currentUser) {
      this.#contextChatURL.value = this.sessionStore.getItem(
        this.#contextChatStorageKey
      );
    }
  }

  get isDrawerActive() {
    return (
      this.#drawerActive.value &&
      (!this.isDrawerInContext || this.isContextDrawerVisible)
    );
  }

  set isDrawerActive(active) {
    this.#drawerActive.value = active;
  }

  get isDrawerExpanded() {
    return (
      this.#drawerExpanded.value &&
      (!this.isDrawerInContext || this.isContextDrawerVisible)
    );
  }

  set isDrawerExpanded(expanded) {
    this.#drawerExpanded.value = expanded;
  }

  get isContextDrawerVisible() {
    return (
      !!this.contextDrawerSlot &&
      this.isDrawerInContext &&
      this.canShowContextDrawer &&
      this.pageShell.selectedContextView.id === "chat"
    );
  }

  get canShowContextDrawer() {
    return (
      !!this.#contextChatURL.value &&
      this.site.desktopView &&
      this.canInteract &&
      !this.isFullPageActive &&
      this.pageShell.canOpenContext &&
      this.pageShell.context === "open"
    );
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
        (this.hasNoPreferredMode ||
          this._store.getObject(PREFERRED_MODE_KEY) === DRAWER_CHAT))
    );
  }

  get hasNoPreferredMode() {
    return !this._store.getObject(PREFERRED_MODE_KEY);
  }

  get isFullPageActive() {
    return this.router.currentRouteName?.startsWith("chat");
  }

  get isActive() {
    return this.isFullPageActive || this.isDrawerActive;
  }

  get canInteract() {
    const routeName = this.router.currentRouteName;
    return routeName !== "wizard" && !routeName?.startsWith("wizard.");
  }

  get isDrawerCollapsed() {
    return this.isDrawerActive && !this.isDrawerExpanded;
  }

  get isPinnedMessagesPaneOpen() {
    return this.router.currentRouteName === "chat.channel.pins";
  }

  get lastKnownAppURL() {
    let url = this._appURL;

    if (!url || url === "/") {
      url = this.router.urlFor(discoveryHomepageRoute());
    }

    return withoutPrefix(url);
  }

  get lastKnownChatURL() {
    const url = this._chatURL;

    if (url) {
      return withoutPrefix(url);
    }

    // On mobile or drawer mode, default to starred channels if user has any
    // On desktop fullscreen, starred channels are shown in the sidebar
    if (
      (this.site.mobileView || this.isDrawerPreferred) &&
      this.chatChannelsManager.hasStarredChannels
    ) {
      return "/chat/starred-channels";
    }

    return "/chat";
  }

  get #contextChatStorageKey() {
    return `chat-context-url:${this.currentUser.id}`;
  }

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

  openDrawer(url) {
    url ??= "/chat";
    let route = this.router.recognize(getURL(url));
    if (route?.localName === "index") {
      route = route.parent;
    }
    if (!route || !this.chatDrawerRouter.canHandleRoute(route)) {
      return;
    }

    this.chat.activeChannel = null;
    const navigation = this.chatDrawerRouter.stateFor(route);
    this.didOpenDrawer(url);
    return navigation;
  }

  didOpenDrawer(url = null) {
    withPluginApi((api) => {
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

    this.isDrawerInContext =
      !!this.currentUser &&
      this.site.desktopView &&
      this.pageShell.openContext();
    this.isDrawerActive = true;
    this.isDrawerExpanded = true;
    if (this.isDrawerInContext) {
      this.#contextChatURL.value = withoutPrefix(url || this.lastKnownChatURL);
      this.sessionStore.setItem(
        this.#contextChatStorageKey,
        this.#contextChatURL.value
      );
      this.pageShell.selectContextView("chat");
    }

    if (url) {
      this.storeChatURL(url);
    }

    this.chat.updatePresence();
    this.#publishStateChange();
  }

  didCloseDrawer() {
    withPluginApi((api) => {
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

    if (
      this.isDrawerInContext &&
      this.pageShell.selectedContextView.id === "chat"
    ) {
      this.pageShell.selectContextView("follow-page");
    }
    this.isDrawerInContext = false;
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
    if (this.isDrawerInContext) {
      return;
    }

    this.isDrawerExpanded = !this.isDrawerExpanded;
    this.isDrawerActive = true;
    this.#publishStateChange();
  }

  registerContextDrawerSlot(element) {
    schedule("afterRender", () => {
      if (this.isDestroying || !element.isConnected) {
        return;
      }

      this.contextDrawerSlot = element;
      if (!this.isDrawerInContext) {
        this.openDrawer(this.#contextChatURL.value);
        return;
      }

      this.chat.updatePresence();
      this.#publishStateChange();
    });

    return () => {
      schedule("afterRender", () => {
        if (this.isDestroying || this.contextDrawerSlot !== element) {
          return;
        }

        this.contextDrawerSlot = null;
        this.chat.updatePresence();
        this.#publishStateChange();
      });
    };
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

  #publishStateChange() {
    const state = {
      isDrawerActive: this.isDrawerActive,
      isDrawerExpanded: this.isDrawerExpanded,
    };

    chatDrawerStateCallbacks.forEach((callback) => callback(state));
  }
}
