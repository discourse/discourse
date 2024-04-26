import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import User from "discourse/models/user";

export default class ChatThreadPreview {
  static create(args = {}) {
    return new ChatThreadPreview(args);
  }

  @tracked replyCount;
  @tracked lastReplyId;
  @tracked lastReplyCreatedAt;
  @tracked lastReplyExcerpt;
  @tracked lastReplyUser;
  @tracked participantCount;
  @tracked participantUsers;

  constructor(args = {}) {
    if (!args) {
      args = {};
    }

    this.replyCount = args.reply_count || args.replyCount || 0;
    this.lastReplyId = args.last_reply_id || args.lastReplyId;
    this.lastReplyCreatedAt = new Date(
      args.last_reply_created_at || args.lastReplyCreatedAt
    );
    this.lastReplyExcerpt = args.last_reply_excerpt || args.lastReplyExcerpt;
    this.lastReplyUser = args.last_reply_user || args.lastReplyUser;
    this.participantCount =
      args.participant_count || args.participantCount || 0;
    this.participantUsers = new TrackedArray(
      args.participant_users || args.participantUsers || []
    );
  }

  get otherParticipantCount() {
    return this.participantCount - this.participantUsers.length;
  }

  updateFromMessageObject(messageObject) {
    const user = User.create(messageObject.user);
    if (!this.participantUsers.find((u) => u.id === user.id)) {
      this.participantUsers.push(user);
      this.participantCount += 1;
    }
    this.lastReplyAt = messageObject.created_at;
    this.lastReplyId = messageObject.id;
    this.lastReplyExcerpt = messageObject.excerpt;
    this.lastReplyUser = user;
  }
}
