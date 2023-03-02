import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { inject as service } from "@ember/service";

export default class ChatChannelPreviewCard extends Component {
  @service chat;
  tagName = "";

  channel = null;

  @readOnly("channel.isOpen") showJoinButton;

  @computed("channel.description")
  get hasDescription() {
    return !isEmpty(this.channel.description);
  }
}
