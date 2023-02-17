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
  },

  didInsertElement() {
    this._super(...arguments);

    this._scrollSidebarToBottom();
    document.addEventListener("keydown", this._autoFocusChatComposer);
  },

  willDestroyElement() {
    this._super(...arguments);

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

  @action
  navigateToIndex() {
    this.router.transitionTo("chat.index");
  },
});
