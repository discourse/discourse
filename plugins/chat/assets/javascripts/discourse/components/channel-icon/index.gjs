import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

export default class ChatChannelIcon extends Component {
  get firstUser() {
    return this.args.channel.chatable.users[0];
  }

  get groupDirectMessage() {
    return (
      this.args.channel.isDirectMessageChannel &&
      this.args.channel.chatable.group
    );
  }

  get groupIsDuoOnly() {
    return (
      this.args.channel.chatable.group &&
      // User array does not include the current user
      this.args.channel.chatable.users.length === 1
    );
  }

  get channelColorStyle() {
    return trustHTML(`color: #${this.args.channel.chatable.color}`);
  }

  get isThreadsList() {
    return this.args.thread ?? false;
  }

  get categoryChannelIcon() {
    return this.channelEmoji || dIcon("d-chat");
  }

  get channelEmoji() {
    const { emoji } = this.args.channel;
    return emoji && dEmoji(emoji);
  }

  <template>
    {{#if @channel.isDirectMessageChannel}}
      {{#if this.groupDirectMessage}}
        {{#if this.channelEmoji}}
          <div class="chat-channel-icon --emoji">
            {{this.channelEmoji}}
          </div>
        {{else if this.groupIsDuoOnly}}
          <div class="chat-channel-icon --avatar">
            <ChatUserAvatar @interactive={{false}} @user={{this.firstUser}} />
          </div>
        {{else}}
          <div class="chat-channel-icon --users-count">
            {{@channel.membershipsCount}}
          </div>
        {{/if}}
      {{else}}
        <div class="chat-channel-icon --avatar">
          <ChatUserAvatar @interactive={{false}} @user={{this.firstUser}} />
        </div>
      {{/if}}
    {{else if @channel.isCategoryChannel}}
      <div class="chat-channel-icon --icon" style={{this.channelColorStyle}}>
        {{this.categoryChannelIcon}}
        {{#if @channel.chatable.read_restricted}}
          {{dIcon "lock" class="chat-channel-icon__restricted-category-icon"}}
        {{/if}}
      </div>
    {{else if this.isThreadsList}}
      <div class="chat-channel-icon --avatar">
        <ChatUserAvatar
          @interactive={{true}}
          @showPresence={{false}}
          @user={{@thread.preview.lastReplyUser}}
        />
        <div class="avatar-flair --threads">
          {{dIcon "discourse-threads"}}
        </div>
      </div>
    {{/if}}
  </template>
}
