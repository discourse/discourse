import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ToggleChannelMembershipButton extends Component {
  @service chat;
  @service chatApi;

  @tracked isLoading = false;

  options = {};

  constructor() {
    super(...arguments);

    this.options = {
      labelType: "normal",
      joinTitle: i18n("chat.channel_settings.join_channel"),
      joinIcon: "",
      joinClass: "",
      leaveTitle: i18n("chat.channel_settings.leave_channel"),
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
        return i18n("chat.channel_settings.leave");
      } else {
        return i18n("chat.channel_settings.join");
      }
    }

    if (this.args.channel.currentUserMembership.following) {
      return i18n("chat.channel_settings.leave_channel");
    } else {
      return i18n("chat.channel_settings.join_channel");
    }
  }

  @action
  onJoinChannel() {
    this.isLoading = true;

    return this.chat
      .followChannel(this.args.channel)
      .then(() => {
        this.args.onJoin?.(this.args.channel);
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
  async onLeaveChannel() {
    this.isLoading = true;

    try {
      if (this.args.channel.chatable.group) {
        await this.chatApi.leaveChannel(this.args.channel.id);
      } else {
        await this.chat.unfollowChannel(this.args.channel);
      }

      this.args.onLeave?.(this.args.channel);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#if @channel.currentUserMembership.following}}
      <DButton
        @action={{this.onLeaveChannel}}
        @translatedLabel={{this.label}}
        @translatedTitle={{this.options.leaveTitle}}
        @icon={{this.options.leaveIcon}}
        @disabled={{this.isLoading}}
        class={{concatClass
          "toggle-channel-membership-button -leave"
          this.options.leaveClass
        }}
      />
    {{else}}
      <PluginOutlet
        @name="chat-join-channel-button"
        @outletArgs={{hash
          onJoinChannel=this.onJoinChannel
          channel=@channel
          icon=this.options.joinIcon
          title=this.options.joinTitle
          label=this.label
          disabled=this.isLoading
        }}
        @defaultGlimmer={{true}}
      >
        <DButton
          @action={{this.onJoinChannel}}
          @translatedLabel={{this.label}}
          @translatedTitle={{this.options.joinTitle}}
          @icon={{this.options.joinIcon}}
          @disabled={{this.isLoading}}
          class={{concatClass
            "toggle-channel-membership-button -join"
            this.options.joinClass
          }}
        />
      </PluginOutlet>
    {{/if}}
  </template>
}
