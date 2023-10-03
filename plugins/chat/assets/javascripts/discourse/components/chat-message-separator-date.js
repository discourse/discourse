import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ChatMessageSeparatorDate extends Component {
  @action
  onDateClick() {
    return this.args.fetchMessagesByDate?.(
      this.args.message.firstMessageOfTheDayAt
    );
  }
}
