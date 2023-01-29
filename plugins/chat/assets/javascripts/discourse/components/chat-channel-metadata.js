import Component from "@glimmer/component";
export default class ChatChannelMetadata extends Component {
  unreadIndicator = false;

  get lastMessageFormatedDate() {
    return moment(this.args.channel.get("last_message_sent_at")).calendar(
      null,
      {
        sameDay: "LT",
        nextDay: "[Tomorrow]",
        nextWeek: "dddd",
        lastDay: "[Yesterday]",
        lastWeek: "dddd",
        sameElse: "l",
      }
    );
  }
}
