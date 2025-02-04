import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ChatChannelMetadata extends Component {
  get lastMessageFormattedDate() {
    const lastMessageDate = this.showThreadUnreadDate
      ? this.args.channel.lastUnreadThreadDate
      : this.args.channel.lastMessage.createdAt;

    return moment(lastMessageDate).calendar(null, {
      sameDay: "LT",
      lastDay: `[${i18n("chat.dates.yesterday")}]`,
      lastWeek: "dddd",
      sameElse: "l",
    });
  }

  get showThreadUnreadDate() {
    return (
      this.args.channel.lastUnreadThreadDate >
      this.args.channel.lastMessage.createdAt
    );
  }

  <template>
    <div class="chat-channel__metadata">
      {{#if @channel.lastMessage}}
        <div class="chat-channel__metadata-date">
          {{this.lastMessageFormattedDate}}
        </div>
      {{/if}}
    </div>
  </template>
}
