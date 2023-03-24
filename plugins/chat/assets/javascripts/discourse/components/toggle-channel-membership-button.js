import Component from "@glimmer/component";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
export default class ToggleChannelMembershipButton extends Component {
  @service chat;
  @tracked isLoading = false;
  onToggle = null;
  options = {};

  constructor() {
    super(...arguments);

    this.options = {
      labelType: "normal",
      joinTitle: I18n.t("chat.channel_settings.join_channel"),
      joinIcon: "",
      joinClass: "",
      leaveTitle: I18n.t("chat.channel_settings.leave_channel"),
      leaveIcon: "",
      leaveClass: "",
      ...this.args.options,
    };
  }

  get label() {
    if (this.options.labelType === "none") {
      return "";
    }

    if (this.options.labelType === "short") {
      if (this.args.channel.currentUserMembership.following) {
        return I18n.t("chat.channel_settings.leave");
      } else {
        return I18n.t("chat.channel_settings.join");
      }
    }

    if (this.args.channel.currentUserMembership.following) {
      return I18n.t("chat.channel_settings.leave_channel");
    } else {
      return I18n.t("chat.channel_settings.join_channel");
    }
  }

  @action
  onJoinChannel() {
    this.isLoading = true;

    return this.chat
      .followChannel(this.args.channel)
      .then(() => {
        this.onToggle?.();
      })
      .catch(popupAjaxError)
      .finally(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.isLoading = false;
      });
  }

  @action
  onLeaveChannel() {
    this.isLoading = true;

    return this.chat
      .unfollowChannel(this.args.channel)
      .then(() => {
        this.onToggle?.();
      })
      .catch(popupAjaxError)
      .finally(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.isLoading = false;
      });
  }
}
