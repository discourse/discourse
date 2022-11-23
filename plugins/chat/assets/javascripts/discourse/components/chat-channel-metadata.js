import Component from "@glimmer/component";

export default class ChatChannelMetadata extends Component {
  unreadIndicator = false;

  get lastMessageFormatedDate() {
    return moment(this.args.channel.last_message_sent_at).calendar(null, {
      sameDay: "hh:mm",
      nextDay: "[Tomorrow]",
      nextWeek: "dddd",
      lastDay: "[Yesterday]",
      lastWeek: "dddd",
      sameElse: "l",
    });
  }
}
