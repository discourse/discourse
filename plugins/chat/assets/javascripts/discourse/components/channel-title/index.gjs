import Component from "@glimmer/component";
import { get, hash } from "@ember/helper";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserStatusMessage from "discourse/components/user-status-message";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

export default class ChatChannelTitle extends Component {
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
    {{#if @channel.isDirectMessageChannel}}
      <div class="chat-channel-title is-dm">
        {{#if this.groupDirectMessage}}
          <span class="chat-channel-title__users-count">
            {{@channel.membershipsCount}}
          </span>
        {{else}}
          <div class="chat-channel-title__avatar">
            <ChatUserAvatar @user={{this.firstUser}} @interactive={{false}} />
          </div>
        {{/if}}

        <div class="chat-channel-title__user-info">
          <div class="chat-channel-title__usernames">
            {{#if this.groupDirectMessage}}
              <span class="chat-channel-title__name">
                {{this.groupsDirectMessageTitle}}
              </span>
            {{else}}
              <span class="chat-channel-title__name">
                {{this.firstUser.username}}
              </span>
              {{#if this.showUserStatus}}
                <UserStatusMessage
                  @class="chat-channel-title__user-status-message"
                  @status={{get this.users "0.status"}}
                  @showDescription={{if this.site.mobileView "true"}}
                />
              {{/if}}
              <PluginOutlet
                @name="after-chat-channel-username"
                @outletArgs={{hash user=@user}}
                @tagName=""
                @connectorTagName=""
              />
            {{/if}}

          </div>
        </div>

        {{#if (has-block)}}
          {{yield}}
        {{/if}}
      </div>
    {{else if @channel.isCategoryChannel}}
      <div class="chat-channel-title is-category">
        <span
          class="chat-channel-title__category-badge"
          style={{this.channelColorStyle}}
        >
          {{icon "d-chat"}}
          {{#if @channel.chatable.read_restricted}}
            {{icon "lock" class="chat-channel-title__restricted-category-icon"}}
          {{/if}}
        </span>
        <span class="chat-channel-title__name">
          {{replaceEmoji @channel.title}}
        </span>

        {{#if (has-block)}}
          {{yield}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
