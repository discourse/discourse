import Component from "@glimmer/component";
import { get, hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserStatusMessage from "discourse/components/user-status-message";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class ChatChannelName extends Component {
  @service currentUser;

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
    return !!(this.users.length === 1 && this.users[0].status);
  }

  <template>
    <div class="chat-channel-name">
      {{#if @channel.isDirectMessageChannel}}
        {{#if this.groupDirectMessage}}
          <span class="chat-channel-name__label">
            {{this.groupsDirectMessageTitle}}
          </span>
        {{else}}
          <span class="chat-channel-name__label">
            {{this.firstUser.username}}
          </span>
          {{#if this.showUserStatus}}
            <UserStatusMessage
              @status={{get this.users "0.status"}}
              @showDescription={{if this.site.mobileView "true"}}
              class="chat-channel__user-status-message"
            />
          {{/if}}
          <PluginOutlet
            @name="after-chat-channel-username"
            @outletArgs={{hash user=@user}}
            @tagName=""
            @connectorTagName=""
          />
        {{/if}}
      {{else if @channel.isCategoryChannel}}
        <span class="chat-channel-name__label">
          {{replaceEmoji @channel.title}}
        </span>

        {{#if (has-block)}}
          {{yield}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
