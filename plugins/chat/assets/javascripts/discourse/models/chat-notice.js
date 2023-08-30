import { tracked } from "@glimmer/tracking";
import MentionWithoutMembership from "discourse/plugins/chat/discourse/components/chat/notices/mention_without_membership";

const COMPONENT_DICT = {
  mention_without_membership: MentionWithoutMembership,
};

export default class ChatNotice {
  static create(args = {}) {
    return new ChatNotice(args);
  }

  @tracked channelId;
  @tracked textContent;

  constructor(args = {}) {
    this.channelId = args.channel_id;
    this.textContent = args.text_content;
    this.type = args.notice_type;
    this.data = args.data;
  }

  get component() {
    return COMPONENT_DICT[this.type];
  }
}
