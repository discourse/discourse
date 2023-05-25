import { tracked } from "@glimmer/tracking";

export default class ChatThreadLastReply {
  static create(channel, args = {}) {
    return new ChatThreadLastReply(channel, args);
  }

  @tracked id;
  @tracked createdAt;
  @tracked excerpt;

  constructor(args = {}) {
    this.id = args.id;
    this.createdAt = args.created_at;
    this.excerpt = args.excerpt;
  }
}
