import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { action } from "@ember/object";
import {
  CHAT_VIEW,
  DRAFT_CHANNEL_VIEW,
  LIST_VIEW,
} from "discourse/plugins/chat/discourse/services/chat";
import { equal } from "@ember/object/computed";
import { cancel, next, throttle } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default Component.extend({
  listView: equal("view", LIST_VIEW),
  chatView: equal("view", CHAT_VIEW),
  draftChannelView: equal("view", DRAFT_CHANNEL_VIEW),
  classNameBindings: [":topic-chat-float-container", "hidden"],
  chat: service(),
  router: service(),
  fullPageChat: service(),
  hidden: true,
  loading: false,
  expanded: true, // TODO - false when not first-load topic
  showClose: true, // TODO - false when on same topic
  sizeTimer: null,
  rafTimer: null,
  view: null,
  hasUnreadMessages: false,

  didInsertElement() {
    this._super(...arguments);
    if (!this.chat.userCanChat) {
      return;
    }

    this._checkSize();
    this.appEvents.on("chat:navigated-to-full-page", this, "close");
    this.appEvents.on("chat:open-view", this, "openView");
    this.appEvents.on("chat:toggle-open", this, "toggleChat");
    this.appEvents.on("chat:toggle-close", this, "close");
    this.appEvents.on(
      "chat:open-channel-for-chatable",
      this,
      "openChannelForChatable"
    );
    this.appEvents.on("chat:open-channel", this, "switchChannel");
    this.appEvents.on(
      "chat:open-channel-at-message",
      this,
      "openChannelAtMessage"
    );
    this.appEvents.on("chat:refresh-channels", this, "refreshChannels");
    this.appEvents.on("composer:closed", this, "_checkSize");
    this.appEvents.on("composer:opened", this, "_checkSize");
    this.appEvents.on("composer:resized", this, "_checkSize");
    this.appEvents.on("composer:div-resizing", this, "_dynamicCheckSize");
    this.appEvents.on(
      "composer:resize-started",
      this,
      "_startDynamicCheckSize"
    );
    this.appEvents.on("composer:resize-ended", this, "_clearDynamicCheckSize");
  },

  willDestroyElement() {
    this._super(...arguments);
    if (!this.chat.userCanChat) {
      return;
    }

    if (this.appEvents) {
      this.appEvents.off("chat:open-view", this, "openView");
      this.appEvents.off("chat:navigated-to-full-page", this, "close");
      this.appEvents.off("chat:toggle-open", this, "toggleChat");
      this.appEvents.off("chat:toggle-close", this, "close");
      this.appEvents.off(
        "chat:open-channel-for-chatable",
        this,
        "openChannelForChatable"
      );
      this.appEvents.off("chat:open-channel", this, "switchChannel");
      this.appEvents.off(
        "chat:open-channel-at-message",
        this,
        "openChannelAtMessage"
      );
      this.appEvents.off("chat:refresh-channels", this, "refreshChannels");
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

  @observes("hidden")
  _fireHiddenAppEvents() {
    this.chat.set("chatOpen", !this.hidden);
    this.appEvents.trigger("chat:rerender-header");
  },

  async openChannelForChatable(channel) {
    if (!channel) {
      return;
    }

    this.switchChannel(channel);
  },

  @discourseComputed("expanded")
  topLineClass(expanded) {
    const baseClass = "topic-chat-drawer-header__top-line";
    return expanded ? `${baseClass}--expanded` : `${baseClass}--collapsed`;
  },

  @discourseComputed("expanded", "chat.activeChannel")
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

  openChannelAtMessage(channel, messageId) {
    this.chat.openChannel(channel, messageId);
  },

  _dynamicCheckSize() {
    if (!this.rafTimer) {
      this.rafTimer = window.requestAnimationFrame(() => {
        this.rafTimer = null;
        this._performCheckSize();
      });
    }
  },

  _startDynamicCheckSize() {
    this.element.classList.add("clear-transitions");
  },

  _clearDynamicCheckSize() {
    this.element.classList.remove("clear-transitions");
    this._checkSize();
  },

  _checkSize() {
    this.sizeTimer = throttle(this, this._performCheckSize, 150);
  },

  _performCheckSize() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const composer = document.getElementById("reply-control");
    const composerIsClosed = composer.classList.contains("closed");
    const minRightMargin = 15;
    this.element.style.setProperty(
      "--composer-right",
      (composerIsClosed
        ? minRightMargin
        : Math.max(minRightMargin, composer.offsetLeft)) + "px"
    );
  },

  @discourseComputed(
    "hidden",
    "expanded",
    "displayMembers",
    "chat.activeChannel",
    "chatView"
  )
  containerClassNames(hidden, expanded, displayMembers, activeChannel) {
    const classNames = ["topic-chat-container"];
    if (expanded) {
      classNames.push("expanded");
    }
    if (!hidden && expanded) {
      classNames.push("visible");
    }
    if (activeChannel) {
      classNames.push(`channel-${activeChannel.id}`);
    }
    return classNames.join(" ");
  },

  @discourseComputed("expanded")
  expandIcon(expanded) {
    if (expanded) {
      return "angle-double-down";
    } else {
      return "angle-double-up";
    }
  },

  @discourseComputed(
    "chat.activeChannel",
    "currentUser.chat_channel_tracking_state"
  )
  unreadCount(activeChannel, trackingState) {
    return trackingState[activeChannel.id]?.unread_count || 0;
  },

  @action
  openView(view) {
    this.setProperties({
      hidden: false,
      expanded: true,
      view,
    });

    this.appEvents.trigger("chat:float-toggled", false);
  },

  @action
  openInFullPage(e) {
    const channel = this.chat.activeChannel;

    this.set("expanded", false);
    this.set("hidden", true);
    this.chat.setActiveChannel(null);
    this.fullPageChat.isPreferred = true;

    if (!channel) {
      return this.router.transitionTo("chat");
    }

    if (e.which === 2) {
      // Middle mouse click
      window
        .open(getURL(`/chat/channel/${channel.id}/${channel.title}`), "_blank")
        .focus();
      return false;
    }

    this.chat.openChannel(channel);
  },

  @action
  toggleExpand() {
    this.set("expanded", !this.expanded);
    this.appEvents.trigger("chat:toggle-expand", this.expanded);
  },

  @action
  close() {
    this.setProperties({
      hidden: true,
      expanded: false,
    });
    this.chat.setActiveChannel(null);
    this.appEvents.trigger("chat:float-toggled", this.hidden);
  },

  @action
  toggleChat() {
    this.set("hidden", !this.hidden);
    this.appEvents.trigger("chat:float-toggled", this.hidden);
    if (this.hidden) {
      return this.chat.setActiveChannel(null);
    } else {
      this.set("expanded", true);
      this.appEvents.trigger("chat:toggle-expand", this.expanded);
      if (this.chat.activeChannel) {
        // Channel was previously open, so after expand we are done.
        return this.chat.setActiveChannel(null);
      }
    }

    // Look for DM channel with unread, and fallback to public channel with unread
    this.chat.getIdealFirstChannelId().then((channelId) => {
      if (channelId) {
        this.chat.getChannelBy("id", channelId).then((channel) => {
          this.switchChannel(channel);
        });
      } else {
        // No channels with unread messages. Fetch channel index.
        this.fetchChannels();
      }
    });
  },

  @action
  refreshChannels() {
    if (this.view === LIST_VIEW) {
      this.fetchChannels();
    }
  },

  @action
  fetchChannels() {
    this.set("loading", true);

    this.chat.getChannels().then(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.setProperties({
        loading: false,
        expanded: true,
        view: LIST_VIEW,
      });

      this.chat.setActiveChannel(null);
    });
  },

  @action
  switchChannel(channel) {
    // we need next here to ensure we correctly let the time for routes transitions
    // eg: deactivate hook of full page chat routes will set activeChannel to null
    next(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.chat.setActiveChannel(channel);

      if (!channel) {
        this.openView(LIST_VIEW);
        return;
      }

      this.openView(CHAT_VIEW);
    });
  },
});
