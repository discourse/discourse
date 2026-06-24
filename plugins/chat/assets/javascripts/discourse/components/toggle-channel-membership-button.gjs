import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class ToggleChannelMembershipButton extends Component {
  @service chat;
  @service chatApi;
  @service chatStateManager;
  @service currentUser;

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
      if (this.isFollowing) {
        return i18n("chat.channel_settings.leave");
      } else {
        return i18n("chat.channel_settings.join");
      }
    }

    if (this.isFollowing) {
      return i18n("chat.channel_settings.leave_channel");
    } else {
      return i18n("chat.channel_settings.join_channel");
    }
  }

  get isFollowing() {
    return this.args.channel.currentUserMembership?.following;
  }

  @action
  onJoinChannel() {
    if (!this.currentUser) {
      if (this.chatStateManager.isDrawerActive) {
        this.chatStateManager.didCloseDrawer();
      }

      this.showLogin();
      return;
    }

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

  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  async onLeaveChannel() {
    this.isLoading = true;

    try {
      // For DM channels (including group DMs), use non-destructive unfollow
      // unless explicitly requested to be destructive (e.g., from settings page)
      if (this.args.channel.chatable.group && this.options.leaveDestructive) {
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
    {{#if this.isFollowing}}
      <DButton
        @action={{this.onLeaveChannel}}
        @translatedLabel={{this.label}}
        @translatedTitle={{this.options.leaveTitle}}
        @icon={{this.options.leaveIcon}}
        @disabled={{this.isLoading}}
        class={{dConcatClass
          "toggle-channel-membership-button -leave"
          this.options.leaveClass
        }}
      />
    {{else}}
      <PluginOutlet
        @name="chat-join-channel-button"
        @outletArgs={{lazyHash
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
          class={{dConcatClass
            "toggle-channel-membership-button -join"
            this.options.joinClass
          }}
        />
      </PluginOutlet>
    {{/if}}
  </template>
}
