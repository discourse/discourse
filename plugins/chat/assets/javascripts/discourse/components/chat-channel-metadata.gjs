import Component from "@glimmer/component";
import { or } from "truth-helpers";
import { i18n } from "discourse-i18n";

export default class ChatChannelMetadata extends Component {
  get lastMessageFormattedDate() {
    const { createdAt, id } = this.args.channel.lastMessage || {};

    if (id === null) {
      return null;
    } else {
      const lastMessageDate = this.showThreadUnreadDate
        ? this.args.channel.lastUnreadThreadDate
        : createdAt;

      return moment(lastMessageDate).calendar(null, {
        sameDay: "LT",
        lastDay: `[${i18n("chat.dates.yesterday")}]`,
        lastWeek: "dddd",
        sameElse: "l",
      });
    }
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
          {{or this.lastMessageFormattedDate "–"}}
        </div>
      {{/if}}
    </div>
  </template>
}
