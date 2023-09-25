import Component from "@glimmer/component";
import MentionWithoutMembership from "discourse/plugins/chat/discourse/components/chat/notices/mention_without_membership";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

const COMPONENT_DICT = {
  mention_without_membership: MentionWithoutMembership,
};

export default class ChatNotices extends Component {
  @service("chat-channel-pane-subscriptions-manager") subscriptionsManager;

  @action
  clearNotice() {
    this.subscriptionsManager.clearNotice(this.args.notice);
  }

  get component() {
    return COMPONENT_DICT[this.args.notice.type];
  }
}
