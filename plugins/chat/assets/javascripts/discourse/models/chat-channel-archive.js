import { tracked } from "@glimmer/tracking";

export default class ChatChannelArchive {
  static create(args = {}) {
    return new ChatChannelArchive(args);
  }

  @tracked failed;
  @tracked completed;
  @tracked messages;
  @tracked topicId;
  @tracked totalMessages;

  constructor(args = {}) {
    this.failed = args.archive_failed;
    this.completed = args.archive_completed;
    this.messages = args.archived_messages;
    this.topicId = args.archive_topic_id;
    this.totalMessages = args.total_messages;
  }
}
