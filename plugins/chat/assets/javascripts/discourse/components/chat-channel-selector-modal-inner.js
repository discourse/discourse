import Component from "@ember/component";
import { action } from "@ember/object";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse-common/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { isPresent } from "@ember/utils";

export default Component.extend({
  chat: service(),
  tagName: "",
  filter: "",
  channels: null,
  searchIndex: 0,
  loading: false,
  chatChannelsManager: service(),
  router: service(),

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
      channel?.set("focused", true);
      this.channels.forEach((c) => {
        if (c !== channel) {
          c.set("focused", false);
        }
      });
    }
  },

  @bind
  onKeyUp(e) {
    if (e.key === "Enter") {
      let focusedChannel = this.channels.find((c) => c.focused);
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
    const indexOfFocused = this.channels.findIndex((c) => c.focused);
    if (indexOfFocused > -1) {
      const nextIndex = direction === "down" ? 1 : -1;
      const nextChannel = this.channels[indexOfFocused + nextIndex];
      if (nextChannel) {
        this.channels[indexOfFocused].set("focused", false);
        nextChannel.set("focused", true);
      }
    } else {
      this.channels[0].set("focused", true);
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
    if (channel.user) {
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
          const channels = searchModel.public_channels.concat(
            searchModel.direct_message_channels,
            searchModel.users
          );
          channels.forEach((c) => {
            if (c.username) {
              c.user = true; // This is used by the `chat-channel-selection-row` component
            }
          });
          this.setProperties({
            channels: channels.map((channel) => {
              return channel.user
                ? ChatChannel.create(channel)
                : this.chatChannelsManager.store(channel);
            }),
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
    channels.forEach((c) => c.set("focused", false));
    channels[0]?.set("focused", true);
  },

  getChannelsWithFilter(filter, opts = { excludeActiveChannel: true }) {
    let sortedChannels = this.chatChannelsManager.channels.sort((a, b) => {
      return new Date(a.last_message_sent_at) > new Date(b.last_message_sent_at)
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
