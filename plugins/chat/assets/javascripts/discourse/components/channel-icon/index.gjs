import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
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
    const { emoji } = this.args.channel;
    return emoji ? dReplaceEmoji(`:${emoji}:`) : dIcon("d-chat");
  }

  get channelEmojiCode() {
    return `:${this.args.channel.emoji}:`;
  }

  <template>
    {{#if @channel.isDirectMessageChannel}}
      {{#if this.groupDirectMessage}}
        {{#if @channel.emoji}}
          <div class="chat-channel-icon --emoji">
            {{dReplaceEmoji this.channelEmojiCode}}
          </div>
        {{else if this.groupIsDuoOnly}}
          <div class="chat-channel-icon --avatar">
            <ChatUserAvatar @user={{this.firstUser}} @interactive={{false}} />
          </div>
        {{else}}
          <div class="chat-channel-icon --users-count">
            {{@channel.membershipsCount}}
          </div>
        {{/if}}
      {{else}}
        <div class="chat-channel-icon --avatar">
          <ChatUserAvatar @user={{this.firstUser}} @interactive={{false}} />
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
          @user={{@thread.preview.lastReplyUser}}
          @interactive={{true}}
          @showPresence={{false}}
        />
        <div class="avatar-flair --threads">
          {{dIcon "discourse-threads"}}
        </div>
      </div>
    {{/if}}
  </template>
}
