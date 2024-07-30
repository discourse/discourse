import { tracked } from "@glimmer/tracking";

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

  constructor(args) {
    this.update(args || {});
  }

  get otherParticipantCount() {
    return this.participantCount - this.participantUsers.length;
  }

  update(args = {}) {
    this.replyCount = args.reply_count ?? args.replyCount ?? 0;
    this.lastReplyId = args.last_reply_id ?? args.lastReplyId;
    this.lastReplyCreatedAt = new Date(
      args.last_reply_created_at ?? args.lastReplyCreatedAt
    );
    this.lastReplyExcerpt = args.last_reply_excerpt ?? args.lastReplyExcerpt;
    this.participantCount =
      args.participant_count ?? args.participantCount ?? 0;

    // cheap trick to avoid avatars flickering
    const lastReplyUser = args.last_reply_user ?? args.lastReplyUser;
    if (lastReplyUser?.id !== this.lastReplyUser?.id) {
      this.lastReplyUser = lastReplyUser;
    }

    // cheap trick to avoid avatars flickering
    const participantUsers =
      args.participant_users ?? args.participantUsers ?? [];
    if (
      participantUsers?.map((u) => u.id).join(",") !==
      this.participantUsers?.map((u) => u.id).join(",")
    ) {
      this.participantUsers = participantUsers;
    }
  }
}
