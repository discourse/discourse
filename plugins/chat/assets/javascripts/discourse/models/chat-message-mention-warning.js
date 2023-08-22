import { tracked } from "@glimmer/tracking";

export default class ChatMessageMentionWarning {
  static create(message, args = {}) {
    return new ChatMessageMentionWarning(message, args);
  }

  @tracked invitationSent = false;
  @tracked cannotSee;
  @tracked withoutMembership;
  @tracked groupsWithTooManyMembers;
  @tracked groupWithMentionsDisabled;

  constructor(message, args = {}) {
    this.message = args.message;
    this.cannotSee = args.cannot_see;
    this.withoutMembership = args.without_membership;
    this.groupsWithTooManyMembers = args.groups_with_too_many_members;
    this.groupWithMentionsDisabled = args.group_mentions_disabled;
  }
}
