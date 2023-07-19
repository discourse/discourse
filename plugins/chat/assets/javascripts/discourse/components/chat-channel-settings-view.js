import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import ChatModalArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";

const NOTIFICATION_LEVELS = [
  { name: I18n.t("chat.notification_levels.never"), value: "never" },
  { name: I18n.t("chat.notification_levels.mention"), value: "mention" },
  { name: I18n.t("chat.notification_levels.always"), value: "always" },
];

const MUTED_OPTIONS = [
  { name: I18n.t("chat.settings.muted_on"), value: true },
  { name: I18n.t("chat.settings.muted_off"), value: false },
];

const AUTO_ADD_USERS_OPTIONS = [
  { name: I18n.t("yes_value"), value: true },
  { name: I18n.t("no_value"), value: false },
];

const THREADING_ENABLED_OPTIONS = [
  { name: I18n.t("chat.settings.threading_enabled"), value: true },
  { name: I18n.t("chat.settings.threading_disabled"), value: false },
];

const CHANNEL_WIDE_MENTIONS_OPTIONS = [
  { name: I18n.t("yes_value"), value: true },
  {
    name: I18n.t("no_value"),
    value: false,
  },
];

export default class ChatChannelSettingsView extends Component {
  @service chat;
  @service chatApi;
  @service chatGuardian;
  @service currentUser;
  @service siteSettings;
  @service router;
  @service dialog;
  @service modal;

  notificationLevels = NOTIFICATION_LEVELS;
  mutedOptions = MUTED_OPTIONS;
  threadingEnabledOptions = THREADING_ENABLED_OPTIONS;
  autoAddUsersOptions = AUTO_ADD_USERS_OPTIONS;
  channelWideMentionsOptions = CHANNEL_WIDE_MENTIONS_OPTIONS;
  isSavingNotificationSetting = false;
  savedDesktopNotificationLevel = false;
  savedMobileNotificationLevel = false;
  savedMuted = false;

  get togglingChannelWideMentionsAvailable() {
    return this.args.channel.isCategoryChannel;
  }

  get togglingThreadingAvailable() {
    return (
      this.siteSettings.enable_experimental_chat_threaded_discussions &&
      this.args.channel.isCategoryChannel &&
      this.currentUser?.admin
    );
  }

  get autoJoinAvailable() {
    return (
      this.siteSettings.max_chat_auto_joined_users > 0 &&
      this.args.channel.isCategoryChannel
    );
  }

  get adminSectionAvailable() {
    return (
      this.chatGuardian.canEditChatChannel() &&
      (this.autoJoinAvailable || this.togglingChannelWideMentionsAvailable)
    );
  }

  get canArchiveChannel() {
    return (
      this.siteSettings.chat_allow_archiving_channels &&
      !this.args.channel.isArchived &&
      !this.args.channel.isReadOnly
    );
  }

  @action
  saveNotificationSettings(frontendKey, backendKey, newValue) {
    if (this.args.channel.currentUserMembership[frontendKey] === newValue) {
      return;
    }

    const settings = {};
    settings[backendKey] = newValue;
    return this.chatApi
      .updateCurrentUserChannelNotificationsSettings(
        this.args.channel.id,
        settings
      )
      .then((result) => {
        this.args.channel.currentUserMembership[frontendKey] =
          result.membership[backendKey];
      });
  }

  @action
  onArchiveChannel() {
    return this.modal.show(ChatModalArchiveChannel, {
      model: { channel: this.args.channel },
    });
  }

  @action
  onDeleteChannel() {
    return this.modal.show(ChatModalDeleteChannel, {
      model: { channel: this.args.channel },
    });
  }

  @action
  onToggleChannelState() {
    this.modal.show(ChatModalToggleChannelStatus, { model: this.args.channel });
  }

  @action
  onToggleAutoJoinUsers() {
    if (!this.args.channel.autoJoinUsers) {
      this.onEnableAutoJoinUsers();
    } else {
      this.onDisableAutoJoinUsers();
    }
  }

  @action
  onToggleThreadingEnabled(value) {
    return this._updateChannelProperty(
      this.args.channel,
      "threading_enabled",
      value
    ).then((result) => {
      this.args.channel.threadingEnabled = result.channel.threading_enabled;
    });
  }

  @action
  onToggleChannelWideMentions() {
    const newValue = !this.args.channel.allowChannelWideMentions;
    if (this.args.channel.allowChannelWideMentions === newValue) {
      return;
    }

    return this._updateChannelProperty(
      this.args.channel,
      "allow_channel_wide_mentions",
      newValue
    ).then((result) => {
      this.args.channel.allowChannelWideMentions =
        result.channel.allow_channel_wide_mentions;
    });
  }

  onDisableAutoJoinUsers() {
    if (this.args.channel.autoJoinUsers === false) {
      return;
    }

    return this._updateChannelProperty(
      this.args.channel,
      "auto_join_users",
      false
    ).then((result) => {
      this.args.channel.autoJoinUsers = result.channel.auto_join_users;
    });
  }

  onEnableAutoJoinUsers() {
    if (this.args.channel.autoJoinUsers === true) {
      return;
    }

    this.dialog.confirm({
      message: I18n.t("chat.settings.auto_join_users_warning", {
        category: this.args.channel.chatable.name,
      }),
      didConfirm: () =>
        this._updateChannelProperty(
          this.args.channel,
          "auto_join_users",
          true
        ).then((result) => {
          this.args.channel.autoJoinUsers = result.channel.auto_join_users;
        }),
    });
  }

  _updateChannelProperty(channel, property, value) {
    const payload = {};
    payload[property] = value;

    return this.chatApi.updateChannel(channel.id, payload).catch((event) => {
      if (event.jqXHR?.responseJSON?.errors) {
        this.flash(event.jqXHR.responseJSON.errors.join("\n"), "error");
      }
    });
  }
}
