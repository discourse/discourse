import Component from "@glimmer/component";
import { get, hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserStatusMessage from "discourse/components/user-status-message";
import replaceEmoji from "discourse/helpers/replace-emoji";
import ChatChannelUnreadIndicator from "../chat-channel-unread-indicator";

export default class ChatChannelName extends Component {
  @service currentUser;

  get unreadIndicator() {
    return this.args.unreadIndicator ?? false;
  }

  get firstUser() {
    return this.args.channel.chatable.users[0];
  }

  get users() {
    return this.args.channel.chatable.users;
  }

  get groupDirectMessage() {
    return (
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.chatable.group
    );
  }

  get groupsDirectMessageTitle() {
    return this.args.channel.title || this.usernames;
  }

  get usernames() {
    return this.users.mapBy("username").join(", ");
  }

  get channelColorStyle() {
    return htmlSafe(`color: #${this.args.channel.chatable.color}`);
  }

  get showUserStatus() {
    if(!this.args.channel.isDirectMessageChannel) {
      return false;
    }
    return !!(this.users.length === 1 && this.users[0].status);
  }

  get channelTitle() {
    if (this.args.channel.isDirectMessageChannel) {
      return this.groupDirectMessage
        ? this.groupsDirectMessageTitle
        : this.firstUser.username;
    }
    return this.args.channel.title;
  }

  get showPluginOutlet() {
    return this.args.channel.isDirectMessageChannel && !this.groupDirectMessage;
  }

  <template>
    <div class="chat-channel-name">
      <div class="chat-channel-name__label">
        {{replaceEmoji this.channelTitle}}

        {{#if this.unreadIndicator}}
          <ChatChannelUnreadIndicator @channel={{@channel}} />
        {{/if}}

        {{#if this.showUserStatus}}
          <UserStatusMessage
            @status={{get this.users "0.status"}}
            @showDescription={{if this.site.mobileView "true"}}
            class="chat-channel__user-status-message"
          />
        {{/if}}

        {{#if this.showPluginOutlet}}
          <PluginOutlet
            @name="after-chat-channel-username"
            @outletArgs={{hash user=@user}}
            @tagName=""
            @connectorTagName=""
          />
        {{/if}}

        {{#if (has-block)}}
          {{yield}}
        {{/if}}
      </div>
    </div>
  </template>
}
