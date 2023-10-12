import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";

export default class ChatChannelPreviewCard extends Component {
  @service chat;

  get showJoinButton() {
    return this.args.channel?.isOpen && this.args.channel?.canJoin;
  }

  get hasDescription() {
    return !isEmpty(this.args.channel?.description);
  }
}
