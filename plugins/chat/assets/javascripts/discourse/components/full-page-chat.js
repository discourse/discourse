import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "",
  router: service(),
  chat: service(),

  init() {
    this._super(...arguments);

    this.appEvents.on("chat:refresh-channels", this, "refreshModel");
    this.appEvents.on("chat:refresh-channel", this, "_refreshChannel");
  },

  didInsertElement() {
    this._super(...arguments);

    this._scrollSidebarToBottom();
    document.addEventListener("keydown", this._autoFocusChatComposer);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("chat:refresh-channels", this, "refreshModel");
    this.appEvents.off("chat:refresh-channel", this, "_refreshChannel");
    document.removeEventListener("keydown", this._autoFocusChatComposer);
  },

  @bind
  _autoFocusChatComposer(event) {
    if (
      !event.key ||
      // Handles things like Enter, Tab, Shift
      event.key.length > 1 ||
      // Don't need to focus if the user is beginning a shortcut.
      event.metaKey ||
      event.ctrlKey ||
      // Space's key comes through as ' ' so it's not covered by event.key
      event.code === "Space" ||
      // ? is used for the keyboard shortcut modal
      event.key === "?"
    ) {
      return;
    }

    if (
      !event.target ||
      /^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName)
    ) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    const composer = document.querySelector(".chat-composer-input");
    if (composer && !this.chat.activeChannel.isDraft) {
      this.appEvents.trigger("chat:insert-text", event.key);
      composer.focus();
    }
  },

  _scrollSidebarToBottom() {
    if (!this.teamsSidebarOn) {
      return;
    }

    const sidebarScroll = document.querySelector(
      ".sidebar-container .scroll-wrapper"
    );
    if (sidebarScroll) {
      sidebarScroll.scrollTop = sidebarScroll.scrollHeight;
    }
  },

  _refreshChannel(channelId) {
    if (this.chat.activeChannel?.id === channelId) {
      this.refreshModel(true);
    }
  },

  @action
  navigateToIndex() {
    this.router.transitionTo("chat.index");
  },

  @action
  switchChannel(channel) {
    return this.chat.openChannel(channel);
  },
});
