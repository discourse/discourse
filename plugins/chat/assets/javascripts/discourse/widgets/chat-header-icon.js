import getURL from "discourse-common/lib/get-url";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";

export default createWidget("header-chat-link", {
  buildKey: () => "header-chat-link",
  chat: null,
  tagName: "li.header-dropdown-toggle.open-chat",
  title: "chat.title",
  services: ["chat", "router", "chatStateManager"],

  html() {
    if (!this.chat.userCanChat) {
      return;
    }

    if (this.currentUser.isInDoNotDisturb()) {
      return this.chatLinkHtml();
    }

    let indicator;
    if (this.chat.unreadUrgentCount) {
      indicator = h(
        "div.chat-channel-unread-indicator.urgent",
        {},
        h(
          "div.number-wrap",
          {},
          h("div.number", {}, this.chat.unreadUrgentCount)
        )
      );
    } else if (this.chat.hasUnreadMessages) {
      indicator = h("div.chat-channel-unread-indicator");
    }

    return this.chatLinkHtml(indicator);
  },

  chatLinkHtml(indicatorNode) {
    return h(
      `a.icon${
        this.chatStateManager.isFullPage || this.chat.chatOpen ? ".active" : ""
      }`,
      { attributes: { tabindex: 0 } },
      [iconNode("comment"), indicatorNode].filter(Boolean)
    );
  },

  mouseUp(e) {
    if (e.which === 2) {
      // Middle mouse click
      window.open(getURL("/chat"), "_blank").focus();
    }
  },

  keyUp(e) {
    if (e.code === "Enter") {
      return this.click();
    }
  },

  click() {
    if (this.chatStateManager.isFullPage && !this.site.mobileView) {
      return;
    }

    return this.router.transitionTo(
      this.chatStateManager.lastKnownChatURL || "chat"
    );
  },

  chatRerenderHeader() {
    this.scheduleRerender();
  },
});
