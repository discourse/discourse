import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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

  get directChannelIcon() {
    const { emoji, membershipsCount } = this.args.channel;
    return emoji ? dReplaceEmoji(`:${emoji}:`) : membershipsCount;
  }

  <template>
    {{#if @channel.isDirectMessageChannel}}
      {{#if this.groupDirectMessage}}
        <div
          class={{dConcatClass
            "chat-channel-icon"
            (unless @channel.emoji "--users-count" "--emoji")
          }}
        >
          {{this.directChannelIcon}}
        </div>
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
