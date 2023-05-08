import Component from "@ember/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse-common/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { isPresent } from "@ember/utils";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import User from "discourse/models/user";

export default Component.extend({
  chat: service(),
  tagName: "",
  filter: "",
  channels: null,
  searchIndex: 0,
  loading: false,
  chatChannelsManager: service(),
  router: service(),
  focusedRow: null,

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("chat-channel-selector-modal:close", this.close);
    document.addEventListener("keyup", this.onKeyUp);
    document
      .getElementById("chat-channel-selector-modal-inner")
      ?.addEventListener("mouseover", this.mouseover);
    document.getElementById("chat-channel-selector-input")?.focus();

    this.getInitialChannels();
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("chat-channel-selector-modal:close", this.close);
    document.removeEventListener("keyup", this.onKeyUp);
    document
      .getElementById("chat-channel-selector-modal-inner")
      ?.removeEventListener("mouseover", this.mouseover);
  },

  @bind
  mouseover(e) {
    if (e.target.classList.contains("chat-channel-selection-row")) {
      let channel;
      const id = parseInt(e.target.dataset.id, 10);
      if (e.target.classList.contains("channel-row")) {
        channel = this.channels.findBy("id", id);
      } else {
        channel = this.channels.find((c) => c.user && c.id === id);
      }
      if (channel) {
        this.set("focusedRow", channel);
      }
    }
  },

  @bind
  onKeyUp(e) {
    if (e.key === "Enter") {
      let focusedChannel = this.channels.find((c) => c === this.focusedRow);
      this.switchChannel(focusedChannel);
      e.preventDefault();
    } else if (e.key === "ArrowDown") {
      this.arrowNavigateChannels("down");
      e.preventDefault();
    } else if (e.key === "ArrowUp") {
      this.arrowNavigateChannels("up");
      e.preventDefault();
    }
  },

  arrowNavigateChannels(direction) {
    const indexOfFocused = this.channels.findIndex(
      (c) => c === this.focusedRow
    );
    if (indexOfFocused > -1) {
      const nextIndex = direction === "down" ? 1 : -1;
      const nextChannel = this.channels[indexOfFocused + nextIndex];
      if (nextChannel) {
        this.set("focusedRow", nextChannel);
      }
    } else {
      this.set("focusedRow", this.channels[0]);
    }

    schedule("afterRender", () => {
      let focusedChannel = document.querySelector(
        "#chat-channel-selector-modal-inner .chat-channel-selection-row.focused"
      );
      focusedChannel?.scrollIntoView({ block: "nearest", inline: "start" });
    });
  },

  @action
  switchChannel(channel) {
    if (channel instanceof User) {
      return this.fetchOrCreateChannelForUser(channel).then((response) => {
        const newChannel = this.chatChannelsManager.store(response.channel);
        return this.chatChannelsManager.follow(newChannel).then((c) => {
          this.router.transitionTo("chat.channel", ...c.routeModels);
          this.close();
        });
      });
    } else {
      return this.chatChannelsManager.follow(channel).then((c) => {
        this.router.transitionTo("chat.channel", ...c.routeModels);
        this.close();
      });
    }
  },

  @action
  search(value) {
    if (isPresent(value?.trim())) {
      discourseDebounce(
        this,
        this.fetchChannelsFromServer,
        value?.trim(),
        INPUT_DELAY
      );
    } else {
      discourseDebounce(this, this.getInitialChannels, INPUT_DELAY);
    }
  },

  @action
  fetchChannelsFromServer(filter) {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    this.setProperties({
      loading: true,
      searchIndex: this.searchIndex + 1,
    });
    const thisSearchIndex = this.searchIndex;
    ajax("/chat/api/chatables", { data: { filter } })
      .then((searchModel) => {
        if (this.searchIndex === thisSearchIndex) {
          this.set("searchModel", searchModel);
          let channels = searchModel.public_channels
            .concat(searchModel.direct_message_channels, searchModel.users)
            .map((c) => {
              if (
                c.chatable_type === "DirectMessage" ||
                c.chatable_type === "Category"
              ) {
                return ChatChannel.create(c);
              }

              return User.create(c);
            });

          this.setProperties({
            channels,
            loading: false,
          });
          this.focusFirstChannel(this.channels);
        }
      })
      .catch(popupAjaxError);
  },

  @action
  getInitialChannels() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    const channels = this.getChannelsWithFilter(this.filter);
    this.set("channels", channels);
    this.focusFirstChannel(channels);
  },

  @action
  fetchOrCreateChannelForUser(user) {
    return ajax("/chat/direct_messages/create.json", {
      method: "POST",
      data: { usernames: [user.username] },
    }).catch(popupAjaxError);
  },

  focusFirstChannel(channels) {
    if (channels[0]) {
      this.set("focusedRow", channels[0]);
    } else {
      this.set("focusedRow", null);
    }
  },

  getChannelsWithFilter(filter, opts = { excludeActiveChannel: true }) {
    let sortedChannels = this.chatChannelsManager.channels.sort((a, b) => {
      return new Date(a.lastMessageSentAt) > new Date(b.lastMessageSentAt)
        ? -1
        : 1;
    });

    const trimmedFilter = filter.trim();
    const lowerCasedFilter = filter.toLowerCase();

    return sortedChannels.filter((channel) => {
      if (
        opts.excludeActiveChannel &&
        this.chat.activeChannel?.id === channel.id
      ) {
        return false;
      }
      if (!trimmedFilter.length) {
        return true;
      }

      if (channel.isDirectMessageChannel) {
        let userFound = false;
        channel.chatable.users.forEach((user) => {
          if (
            user.username.toLowerCase().includes(lowerCasedFilter) ||
            user.name?.toLowerCase().includes(lowerCasedFilter)
          ) {
            return (userFound = true);
          }
        });
        return userFound;
      } else {
        return channel.title.toLowerCase().includes(lowerCasedFilter);
      }
    });
  },
});
