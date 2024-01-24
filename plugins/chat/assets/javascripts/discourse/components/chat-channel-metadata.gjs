import Component from "@glimmer/component";
import ChatChannelUnreadIndicator from "./chat-channel-unread-indicator";

export default class ChatChannelMetadata extends Component {
  get unreadIndicator() {
    return this.args.unreadIndicator ?? false;
  }

  get lastMessageFormattedDate() {
    return moment(this.args.channel.lastMessage.createdAt).calendar(null, {
      sameDay: "LT",
      nextDay: "[Tomorrow]",
      nextWeek: "dddd",
      lastDay: "[Yesterday]",
      lastWeek: "dddd",
      sameElse: "l",
    });
  }

  <template>
    <div class="chat-channel__metadata">
      {{#if @channel.lastMessage}}
        <div class="chat-channel__metadata-date">
          {{this.lastMessageFormattedDate}}
        </div>
      {{/if}}

      {{#if this.unreadIndicator}}
        <ChatChannelUnreadIndicator @channel={{@channel}} />
      {{/if}}
    </div>
  </template>
}
