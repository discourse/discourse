import { caretPosition } from "discourse/lib/utilities";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { inject as service } from "@ember/service";
import { schedule } from "@ember/runloop";
import { gt, not } from "@ember/object/computed";
import { createDirectMessageChannelDraft } from "discourse/plugins/chat/discourse/models/chat-channel";

export default Component.extend({
  tagName: "",
  users: null,
  selectedUsers: null,
  term: null,
  isFiltering: false,
  isFilterFocused: false,
  highlightedSelectedUser: null,
  focusedUser: null,
  chat: service(),
  router: service(),
  chatStateManager: service(),
  isLoading: false,

  init() {
    this._super(...arguments);

    this.set("users", []);
    this.set("selectedUsers", []);
    this.set("channel", createDirectMessageChannelDraft());
  },

  didInsertElement() {
    this._super(...arguments);

    this.filterUsernames();
  },

  didReceiveAttrs() {
    this._super(...arguments);

    this.set("term", null);

    this.focusFilter();

    if (!this.hasSelection) {
      this.filterUsernames();
    }
  },

  hasSelection: gt("channel.chatable.users.length", 0),

  @discourseComputed
  chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  },

  @bind
  filterUsernames(term = null) {
    this.set("isFiltering", true);

    this.chat
      .searchPossibleDirectMessageUsers({
        term,
        limit: 6,
        exclude: this.channel.chatable?.users?.mapBy("username") || [],
        lastSeenUsers: isEmpty(term) ? true : false,
      })
      .then((r) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        if (r !== "__CANCELLED") {
          this.set("users", r.users || []);
          this.set("focusedUser", this.users.firstObject);
        }
      })
      .finally(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isFiltering", false);
      });
  },

  shouldRenderResults: not("isFiltering"),

  @action
  selectUser(user) {
    this.selectedUsers.pushObject(user);
    this.users.removeObject(user);
    this.set("users", []);
    this.set("focusedUser", null);
    this.set("highlightedSelectedUser", null);
    this.set("term", null);
    this.focusFilter();
    this.onChangeSelectedUsers?.(this.selectedUsers);
  },

  @action
  deselectUser(user) {
    this.users.removeObject(user);
    this.selectedUsers.removeObject(user);
    this.set("focusedUser", this.users.firstObject);
    this.set("highlightedSelectedUser", null);
    this.set("term", null);

    if (isEmpty(this.selectedUsers)) {
      this.filterUsernames();
    }

    this.focusFilter();
    this.onChangeSelectedUsers?.(this.selectedUsers);
  },

  @action
  focusFilter() {
    this.set("isFilterFocused", true);

    schedule("afterRender", () => {
      document.querySelector(".filter-usernames")?.focus();
    });
  },

  @action
  onFilterInput(term) {
    this.set("term", term);
    this.set("users", []);

    if (!term?.length) {
      return;
    }

    this.set("isFiltering", true);

    discourseDebounce(this, this.filterUsernames, term, INPUT_DELAY);
  },

  @action
  handleUserKeyUp(user, event) {
    if (event.key === "Enter") {
      event.stopPropagation();
      event.preventDefault();
      this.selectUser(user);
    }
  },

  @action
  onFilterInputFocusOut() {
    this.set("isFilterFocused", false);
    this.set("highlightedSelectedUser", null);
  },

  @action
  leaveChannel() {
    this.router.transitionTo("chat.index");
  },

  @action
  handleFilterKeyUp(event) {
    if (event.key === "Tab") {
      const enabledComposer = document.querySelector(".chat-composer-input");
      if (enabledComposer && !enabledComposer.disabled) {
        event.preventDefault();
        event.stopPropagation();
        enabledComposer.focus();
      }
    }

    if (
      (event.key === "Enter" || event.key === "Backspace") &&
      this.highlightedSelectedUser
    ) {
      event.preventDefault();
      event.stopPropagation();
      this.deselectUser(this.highlightedSelectedUser);
      return;
    }

    if (event.key === "Backspace" && isEmpty(this.term) && this.hasSelection) {
      event.preventDefault();
      event.stopPropagation();

      this.deselectUser(this.channel.chatable.users.lastObject);
    }

    if (event.key === "Enter" && this.focusedUser) {
      event.preventDefault();
      event.stopPropagation();
      this.selectUser(this.focusedUser);
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      this._handleVerticalArrowKeys(event);
    }

    if (event.key === "Escape" && this.highlightedSelectedUser) {
      this.set("highlightedSelectedUser", null);
    }

    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      this._handleHorizontalArrowKeys(event);
    }
  },

  _firstSelectWithArrows(event) {
    if (event.key === "ArrowRight") {
      return;
    }

    if (event.key === "ArrowLeft") {
      const position = caretPosition(
        document.querySelector(".filter-usernames")
      );
      if (position > 0) {
        return;
      } else {
        event.preventDefault();
        event.stopPropagation();
        this.set(
          "highlightedSelectedUser",
          this.channel.chatable.users.lastObject
        );
      }
    }
  },

  _changeSelectionWithArrows(event) {
    if (event.key === "ArrowRight") {
      if (
        this.highlightedSelectedUser === this.channel.chatable.users.lastObject
      ) {
        this.set("highlightedSelectedUser", null);
        return;
      }

      if (this.channel.chatable.users.length === 1) {
        return;
      }

      this._highlightNextSelectedUser(event.key === "ArrowLeft" ? -1 : 1);
    }

    if (event.key === "ArrowLeft") {
      if (this.channel.chatable.users.length === 1) {
        return;
      }

      this._highlightNextSelectedUser(event.key === "ArrowLeft" ? -1 : 1);
    }
  },

  _highlightNextSelectedUser(modifier) {
    const newIndex =
      this.channel.chatable.users.indexOf(this.highlightedSelectedUser) +
      modifier;

    if (this.channel.chatable.users.objectAt(newIndex)) {
      this.set(
        "highlightedSelectedUser",
        this.channel.chatable.users.objectAt(newIndex)
      );
    } else {
      this.set(
        "highlightedSelectedUser",
        event.key === "ArrowLeft"
          ? this.channel.chatable.users.lastObject
          : this.channel.chatable.users.firstObject
      );
    }
  },

  _handleHorizontalArrowKeys(event) {
    const position = caretPosition(document.querySelector(".filter-usernames"));
    if (position > 0) {
      return;
    }

    if (!this.highlightedSelectedUser) {
      this._firstSelectWithArrows(event);
    } else {
      this._changeSelectionWithArrows(event);
    }
  },

  _handleVerticalArrowKeys(event) {
    if (isEmpty(this.users)) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    if (!this.focusedUser) {
      this.set("focusedUser", this.users.firstObject);
      return;
    }

    const modifier = event.key === "ArrowUp" ? -1 : 1;
    const newIndex = this.users.indexOf(this.focusedUser) + modifier;

    if (this.users.objectAt(newIndex)) {
      this.set("focusedUser", this.users.objectAt(newIndex));
    } else {
      this.set(
        "focusedUser",
        event.key === "ArrowUp" ? this.users.lastObject : this.users.firstObject
      );
    }
  },
});
