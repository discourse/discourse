import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { isPresent } from "@ember/utils";
export default class ChatChannelLeaveBtn extends Component {
  @service chat;
  @service site;

  get shouldRender() {
    return !this.site.mobileView && isPresent(this.args.channel);
  }

  get leaveChatTitleKey() {
    if (this.args.channel.isDirectMessageChannel) {
      return "chat.direct_messages.leave";
    } else {
      return "chat.leave";
    }
  }
}
