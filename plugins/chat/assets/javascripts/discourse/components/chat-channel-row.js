import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default Component.extend({
  tagName: "",
  router: service(),
  chat: service(),
  channel: null,
  switchChannel: null,
  isDirectMessageRow: equal(
    "channel.chatable_type",
    CHATABLE_TYPES.directMessageChannel
  ),
  options: null,

  didInsertElement() {
    this._super(...arguments);

    if (this.isDirectMessageRow) {
      this.channel.chatable.users[0].trackStatus();
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.isDirectMessageRow) {
      this.channel.chatable.users[0].stopTrackingStatus();
    }
  },

  @discourseComputed(
    "channel.id",
    "chat.activeChannel.id",
    "router.currentRouteName"
  )
  active(channelId, activeChannelId, currentRouteName) {
    return (
      currentRouteName?.startsWith("chat.channel") &&
      channelId === activeChannelId
    );
  },

  @discourseComputed("active", "channel.{id,muted}", "channel.focused")
  rowClassNames(active, channel, focused) {
    const classes = ["chat-channel-row", `chat-channel-${channel.id}`];
    if (active) {
      classes.push("active");
    }
    if (focused) {
      classes.push("focused");
    }
    if (channel.current_user_membership.muted) {
      classes.push("muted");
    }
    return classes.join(" ");
  },

  @discourseComputed(
    "isDirectMessageRow",
    "channel.chatable.users.[]",
    "channel.chatable.users.@each.status"
  )
  showUserStatus(isDirectMessageRow) {
    return !!(
      isDirectMessageRow &&
      this.channel.chatable.users.length === 1 &&
      this.channel.chatable.users[0].status
    );
  },

  @action
  handleNewWindow(event) {
    // Middle mouse click
    if (event.which === 2) {
      window
        .open(
          getURL(`/chat/channel/${this.channel.id}/${this.channel.title}`),
          "_blank"
        )
        .focus();
    }
  },

  @action
  handleSwitchChannel(event) {
    if (this.switchChannel) {
      this.switchChannel(this.channel);
      event.preventDefault();
    }
  },

  @action
  handleClick(event) {
    if (event.target.classList.contains("chat-channel-leave-btn")) {
      return true;
    }

    if (
      event.target.classList.contains("chat-channel-settings-btn") ||
      event.target.parentElement.classList.contains("select-kit-header-wrapper")
    ) {
      return;
    }

    this.handleSwitchChannel(event);
  },

  @action
  handleKeyUp(event) {
    if (event.key !== "Enter") {
      return;
    }

    this.handleSwitchChannel(event);
  },

  @discourseComputed("channel.chatable_type")
  leaveChatTitle() {
    if (this.channel.isDirectMessageChannel) {
      return I18n.t("chat.direct_messages.leave");
    } else {
      return I18n.t("chat.channel_settings.leave_channel");
    }
  },
});
