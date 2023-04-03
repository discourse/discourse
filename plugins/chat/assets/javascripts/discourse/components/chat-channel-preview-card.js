import Component from "@glimmer/component";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";

export default class ChatChannelPreviewCard extends Component {
  @service chat;

  get showJoinButton() {
    return this.args.channel?.isOpen;
  }

  get hasDescription() {
    return !isEmpty(this.args.channel?.description);
  }
}
