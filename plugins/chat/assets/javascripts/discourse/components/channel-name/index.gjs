import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import ChatChannelUnreadIndicator from "../chat-channel-unread-indicator";

export default class ChatChannelName extends Component {
  @service currentUser;
  @service siteSettings;

  get unreadIndicator() {
    return this.args.unreadIndicator ?? false;
  }

  get users() {
    return this.args.channel.chatable.users;
  }

  get prefersName() {
    return (
      this.siteSettings.enable_names &&
      this.siteSettings.display_name_on_posts &&
      !this.siteSettings.prioritize_username_in_ux
    );
  }

  get directMessageTitle() {
    if (this.users.length === 0) {
      return this.prefersName
        ? this.currentUser.name || this.currentUser.username
        : this.currentUser.username;
    }
    return this.prefersName
      ? this.users.map((user) => user.name || user.username).join(", ")
      : this.users.map((user) => user.username).join(", ");
  }

  get channelColorStyle() {
    return trustHTML(`color: #${this.args.channel.chatable.color}`);
  }

  get showUserStatus() {
    if (!this.args.channel.isDirectMessageChannel) {
      return false;
    }
    return !!(this.users.length === 1 && this.users[0].status);
  }

  get channelTitle() {
    if (this.args.channel.isDirectMessageChannel) {
      return this.args.channel.displayTitle ?? this.directMessageTitle;
    }

    return this.args.channel.displayTitle;
  }

  get showPluginOutlet() {
    return (
      this.args.channel.isDirectMessageChannel &&
      !this.args.channel.chatable.group
    );
  }

  <template>
    <div class="chat-channel-name">
      <div class="chat-channel-name__label">
        {{dReplaceEmoji this.channelTitle}}

        {{#if this.showUserStatus}}
          <DUserStatusMessage
            @status={{get this.users "0.status"}}
            @showDescription={{if this.site.mobileView "true"}}
            class="chat-channel__user-status-message"
          />
        {{/if}}

        <PluginOutlet
          @name="after-chat-channel-username"
          @outletArgs={{if this.showPluginOutlet (lazyHash user=@user)}}
        />

        {{#if (has-block)}}
          {{yield}}
        {{/if}}
      </div>

      {{#if this.unreadIndicator}}
        <ChatChannelUnreadIndicator @channel={{@channel}} />
      {{/if}}
    </div>
  </template>
}
