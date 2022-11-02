import Component from "@ember/component";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action, computed } from "@ember/object";

export default class ToggleChannelMembershipButton extends Component {
  @service chat;

  tagName = "";
  channel = null;
  onToggle = null;
  options = null;
  isLoading = false;

  init() {
    super.init(...arguments);

    this.set(
      "options",
      Object.assign(
        {
          labelType: "normal",
          joinTitle: I18n.t("chat.channel_settings.join_channel"),
          joinIcon: "",
          joinClass: "",
          leaveTitle: I18n.t("chat.channel_settings.leave_channel"),
          leaveIcon: "",
          leaveClass: "",
        },
        this.options || {}
      )
    );
  }

  @computed("channel.current_user_membership.following")
  get label() {
    if (this.options.labelType === "none") {
      return "";
    }

    if (this.options.labelType === "short") {
      if (this.channel.isFollowing) {
        return I18n.t("chat.channel_settings.leave");
      } else {
        return I18n.t("chat.channel_settings.join");
      }
    }

    if (this.channel.isFollowing) {
      return I18n.t("chat.channel_settings.leave_channel");
    } else {
      return I18n.t("chat.channel_settings.join_channel");
    }
  }

  @action
  onJoinChannel() {
    this.set("isLoading", true);

    return this.chat
      .followChannel(this.channel)
      .then(() => {
        this.onToggle?.();
      })
      .catch(popupAjaxError)
      .finally(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isLoading", false);
      });
  }

  @action
  onLeaveChannel() {
    this.set("isLoading", true);

    return this.chat
      .unfollowChannel(this.channel)
      .then(() => {
        this.onToggle?.();
      })
      .catch(popupAjaxError)
      .finally(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("isLoading", false);
      });
  }
}
