import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import MentionWithoutMembership from "discourse/plugins/chat/discourse/components/chat/notices/mention_without_membership";

const COMPONENT_DICT = {
  mention_without_membership: MentionWithoutMembership,
};

export default class ChatNotices extends Component {
  @service("chat-channel-notices-manager") noticesManager;

  @action
  clearNotice() {
    this.noticesManager.clearNotice(this.args.notice);
  }

  get component() {
    return COMPONENT_DICT[this.args.notice.type];
  }
}
