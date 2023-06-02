import { tracked } from "@glimmer/tracking";

export default class ChatThreadPreview {
  static create(args = {}) {
    return new ChatThreadPreview(args);
  }

  @tracked lastReplyId;
  @tracked lastReplyCreatedAt;
  @tracked lastReplyExcerpt;
  @tracked lastReplyUser;
  @tracked participantCount;
  @tracked participantUsers;

  constructor(args = {}) {
    this.lastReplyId = args.last_reply_id || args.lastReplyId;
    this.lastReplyCreatedAt =
      args.last_reply_created_at || args.lastReplyCreatedAt;
    this.lastReplyExcerpt = args.last_reply_excerpt || args.lastReplyExcerpt;
    this.lastReplyUser = args.last_reply_user || args.lastReplyUser;
    this.participantCount = args.participant_count || args.participantCount;
    this.participantUsers = args.participant_users || args.participantUsers;
  }

  get otherParticipantCount() {
    return this.participantCount - this.participantUsers.length;
  }
}
