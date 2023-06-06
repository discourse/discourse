import { tracked } from "@glimmer/tracking";

export default class ChatThreadPreview {
  static create(args = {}) {
    return new ChatThreadPreview(args);
  }

  @tracked lastReplyId;
  @tracked lastReplyCreatedAt;
  @tracked lastReplyExcerpt;

  constructor(args = {}) {
    this.lastReplyId = args.last_reply_id || args.lastReplyId;
    this.lastReplyCreatedAt =
      args.last_reply_created_at || args.lastReplyCreatedAt;
    this.lastReplyExcerpt = args.last_reply_excerpt || args.lastReplyExcerpt;
  }
}
