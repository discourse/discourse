import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import ChatApi from "discourse/plugins/chat/discourse/lib/chat-api";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import { camelize } from "@ember/string";
import discourseLater from "discourse-common/lib/later";

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
  { name: I18n.t("chat.settings.enable_auto_join_users"), value: true },
  { name: I18n.t("chat.settings.disable_auto_join_users"), value: false },
];

export default class ChatChannelSettingsView extends Component {
  @service chat;
  @service router;
  @service dialog;
  tagName = "";
  channel = null;

  notificationLevels = NOTIFICATION_LEVELS;
  mutedOptions = MUTED_OPTIONS;
  autoAddUsersOptions = AUTO_ADD_USERS_OPTIONS;
  isSavingNotificationSetting = false;
  savedDesktopNotificationLevel = false;
  savedMobileNotificationLevel = false;
  savedMuted = false;

  _updateAutoJoinUsers(value) {
    return ChatApi.modifyChatChannel(this.channel.id, {
      auto_join_users: value,
    })
      .then((chatChannel) => {
        this.channel.set("auto_join_users", chatChannel.auto_join_users);
      })
      .catch((event) => {
        if (event.jqXHR?.responseJSON?.errors) {
          this.flash(event.jqXHR.responseJSON.errors.join("\n"), "error");
        }
      });
  }

  @action
  saveNotificationSettings(key, value) {
    if (this.channel[key] === value) {
      return;
    }

    const camelizedKey = camelize(`saved_${key}`);
    this.set(camelizedKey, false);

    const settings = {};
    settings[key] = value;
    return ChatApi.updateChatChannelNotificationsSettings(
      this.channel.id,
      settings
    )
      .then((membership) => {
        this.channel.current_user_membership.setProperties({
          muted: membership.muted,
          desktop_notification_level: membership.desktop_notification_level,
          mobile_notification_level: membership.mobile_notification_level,
        });
        this.set(camelizedKey, true);
      })
      .finally(() => {
        discourseLater(() => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          this.set(camelizedKey, false);
        }, 2000);
      });
  }

  @computed(
    "siteSettings.chat_allow_archiving_channels",
    "channel.{isArchived,isReadOnly}"
  )
  get canArchiveChannel() {
    return (
      this.siteSettings.chat_allow_archiving_channels &&
      !this.channel.isArchived &&
      !this.channel.isReadOnly
    );
  }

  @computed("channel.isCategoryChannel")
  get autoJoinAvailable() {
    return (
      this.siteSettings.max_chat_auto_joined_users > 0 &&
      this.channel.isCategoryChannel
    );
  }

  @action
  onArchiveChannel() {
    const controller = showModal("chat-channel-archive-modal");
    controller.set("chatChannel", this.channel);
  }

  @action
  onDeleteChannel() {
    const controller = showModal("chat-channel-delete-modal");
    controller.set("chatChannel", this.channel);
  }

  @action
  onToggleChannelState() {
    const controller = showModal("chat-channel-toggle");
    controller.set("chatChannel", this.channel);
  }

  @action
  onToggleAutoJoinUsers() {
    if (!this.channel.auto_join_users) {
      this.onEnableAutoJoinUsers();
    } else {
      this.onDisableAutoJoinUsers();
    }
  }

  onDisableAutoJoinUsers() {
    this._updateAutoJoinUsers(false);
  }

  onEnableAutoJoinUsers() {
    this.dialog.confirm({
      message: I18n.t("chat.settings.auto_join_users_warning", {
        category: this.channel.chatable.name,
      }),
      didConfirm: () => this._updateAutoJoinUsers(true),
    });
  }
}
