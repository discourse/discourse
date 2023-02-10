import Component from "@ember/component";
import discourseComputed, {
  bind,
  observes,
} from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { cancel, throttle } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export default Component.extend({
  tagName: "",
  chat: service(),
  router: service(),
  chatDrawerSize: service(),
  chatChannelsManager: service(),
  chatStateManager: service(),
  chatDrawerRouter: service(),
  loading: false,
  sizeTimer: null,
  rafTimer: null,
  hasUnreadMessages: false,
  drawerStyle: null,

  didInsertElement() {
    this._super(...arguments);
    if (!this.chat.userCanChat) {
      return;
    }

    this._checkSize();
    this.appEvents.on("chat:open-url", this, "openURL");
    this.appEvents.on("chat:toggle-close", this, "close");
    this.appEvents.on("chat:open-channel", this, "switchChannel");
    this.appEvents.on(
      "chat:open-channel-at-message",
      this,
      "openChannelAtMessage"
    );
    this.appEvents.on("composer:closed", this, "_checkSize");
    this.appEvents.on("composer:opened", this, "_checkSize");
    this.appEvents.on("composer:resized", this, "_checkSize");
    this.appEvents.on("composer:div-resizing", this, "_dynamicCheckSize");
    window.addEventListener("resize", this._checkSize);
    this.appEvents.on(
      "composer:resize-started",
      this,
      "_startDynamicCheckSize"
    );
    this.appEvents.on("composer:resize-ended", this, "_clearDynamicCheckSize");

    this.computeDrawerStyle();
  },

  willDestroyElement() {
    this._super(...arguments);
    if (!this.chat.userCanChat) {
      return;
    }

    window.removeEventListener("resize", this._checkSize);

    if (this.appEvents) {
      this.appEvents.off("chat:open-url", this, "openURL");
      this.appEvents.off("chat:toggle-close", this, "close");
      this.appEvents.off("chat:open-channel", this, "switchChannel");
      this.appEvents.off(
        "chat:open-channel-at-message",
        this,
        "openChannelAtMessage"
      );
      this.appEvents.off("composer:closed", this, "_checkSize");
      this.appEvents.off("composer:opened", this, "_checkSize");
      this.appEvents.off("composer:resized", this, "_checkSize");
      this.appEvents.off("composer:div-resizing", this, "_dynamicCheckSize");
      this.appEvents.off(
        "composer:resize-started",
        this,
        "_startDynamicCheckSize"
      );
      this.appEvents.off(
        "composer:resize-ended",
        this,
        "_clearDynamicCheckSize"
      );
    }
    if (this.sizeTimer) {
      cancel(this.sizeTimer);
      this.sizeTimer = null;
    }
    if (this.rafTimer) {
      window.cancelAnimationFrame(this.rafTimer);
    }
  },

  @observes("chatStateManager.isDrawerActive")
  _fireHiddenAppEvents() {
    this.appEvents.trigger("chat:rerender-header");
  },

  @discourseComputed("chatStateManager.isDrawerExpanded", "chat.activeChannel")
  displayMembers(expanded, channel) {
    return expanded && !channel?.isDirectMessageChannel;
  },

  @discourseComputed("displayMembers")
  infoTabRoute(displayMembers) {
    if (displayMembers) {
      return "chat.channel.info.members";
    }

    return "chat.channel.info.settings";
  },

  computeDrawerStyle() {
    const { width, height } = this.chatDrawerSize.size;
    let style = `width: ${escapeExpression((width || "0").toString())}px;`;
    style += `height: ${escapeExpression((height || "0").toString())}px;`;
    this.set("drawerStyle", htmlSafe(style));
  },

  openChannelAtMessage(channel, messageId) {
    this.chat.openChannel(channel, messageId);
  },

  @bind
  _dynamicCheckSize() {
    if (!this.chatStateManager.isDrawerActive) {
      return;
    }

    if (this.rafTimer) {
      return;
    }

    this.rafTimer = window.requestAnimationFrame(() => {
      this.rafTimer = null;
      this._performCheckSize();
    });
  },

  _startDynamicCheckSize() {
    if (!this.chatStateManager.isDrawerActive) {
      return;
    }

    document.querySelector(".chat-drawer").classList.add("clear-transitions");
  },

  _clearDynamicCheckSize() {
    if (!this.chatStateManager.isDrawerActive) {
      return;
    }

    document
      .querySelector(".chat-drawer")
      .classList.remove("clear-transitions");
    this._checkSize();
  },

  @bind
  _checkSize() {
    this.sizeTimer = throttle(this, this._performCheckSize, 150);
  },

  _performCheckSize() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const drawerContainer = document.querySelector(
      ".chat-drawer-outlet-container"
    );
    if (!drawerContainer) {
      return;
    }

    const composer = document.getElementById("reply-control");
    const composerIsClosed = composer.classList.contains("closed");
    const minRightMargin = 15;

    drawerContainer.style.setProperty(
      "--composer-right",
      (composerIsClosed
        ? minRightMargin
        : Math.max(minRightMargin, composer.offsetLeft)) + "px"
    );
  },

  @discourseComputed("chat.activeChannel.currentUserMembership.unread_count")
  unreadCount(count) {
    return count || 0;
  },

  @action
  openURL(URL = null) {
    this.chat.activeChannel = null;
    this.chatStateManager.didOpenDrawer(URL);
    this.chatDrawerRouter.stateFor(this._routeFromURL(URL));
  },

  _routeFromURL(URL) {
    let route = this.router.recognize(URL || "/");

    // ember might recognize the index subroute
    if (route.localName === "index") {
      route = route.parent;
    }

    return route;
  },

  @action
  openInFullPage() {
    this.chatStateManager.storeAppURL();
    this.chatStateManager.prefersFullPage();
    this.chat.activeChannel = null;

    return this.router.transitionTo(this.chatStateManager.lastKnownChatURL);
  },

  @action
  toggleExpand() {
    this.computeDrawerStyle();
    this.chatStateManager.didToggleDrawer();
    this.appEvents.trigger(
      "chat:toggle-expand",
      this.chatStateManager.isDrawerExpanded
    );
  },

  @action
  close() {
    this.computeDrawerStyle();
    this.chatStateManager.didCloseDrawer();
    this.chat.activeChannel = null;
  },

  @action
  didResize(element, { width, height }) {
    this.chatDrawerSize.size = { width, height };
  },
});
