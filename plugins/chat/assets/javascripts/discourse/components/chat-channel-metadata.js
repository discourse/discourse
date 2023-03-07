import Component from "@glimmer/component";

export default class ChatChannelMetadata extends Component {
  get unreadIndicator() {
    return this.args.unreadIndicator ?? false;
  }

  get lastMessageFormatedDate() {
    return moment(this.args.channel.lastMessageSentAt).calendar(null, {
      sameDay: "LT",
      nextDay: "[Tomorrow]",
      nextWeek: "dddd",
      lastDay: "[Yesterday]",
      lastWeek: "dddd",
      sameElse: "l",
    });
  }
}
