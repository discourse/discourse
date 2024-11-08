import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import icon from "discourse-common/helpers/d-icon";
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
    return htmlSafe(`color: #${this.args.channel.chatable.color}`);
  }

  get isThreadsList() {
    return this.args.thread ?? false;
  }

  <template>
    {{#if @channel.isDirectMessageChannel}}
      <div class="chat-channel-icon">
        {{#if @channel.iconUploadUrl}}
          <span class="chat-channel-icon --avatar --custom-icon">
            <img src={{@channel.iconUploadUrl}} />
          </span>
        {{else if this.groupDirectMessage}}
          <span class="chat-channel-icon --users-count">
            {{@channel.membershipsCount}}
          </span>
        {{else}}
          <div class="chat-channel-icon --avatar">
            <ChatUserAvatar @user={{this.firstUser}} @interactive={{false}} />
          </div>
        {{/if}}
      </div>
    {{else if @channel.isCategoryChannel}}
      <div class="chat-channel-icon">
        <span
          class="chat-channel-icon --category-badge"
          style={{this.channelColorStyle}}
        >
          {{icon "d-chat"}}
          {{#if @channel.chatable.read_restricted}}
            {{icon "lock" class="chat-channel-icon__restricted-category-icon"}}
          {{/if}}
        </span>
      </div>
    {{else if this.isThreadsList}}
      <div class="chat-channel-icon">
        <div class="chat-channel-icon --avatar">
          <ChatUserAvatar
            @user={{@thread.preview.lastReplyUser}}
            @interactive={{true}}
            @showPresence={{false}}
          />
          <div class="avatar-flair --threads">
            {{icon "discourse-threads"}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
