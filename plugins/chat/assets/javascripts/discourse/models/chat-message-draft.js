import { tracked } from "@glimmer/tracking";

export default class ChatMessageDraft {
  static create(args = {}) {
    return new ChatMessageDraft(args ?? {});
  }

  @tracked uploads;
  @tracked message;
  @tracked _replyToMsg;

  constructor(args = {}) {
    this.message = args.message ?? "";
    this.uploads = args.uploads ?? [];
    this.replyToMsg = args.replyToMsg;
  }

  get replyToMsg() {
    return this._replyToMsg;
  }

  set replyToMsg(message) {
    this._replyToMsg = message
      ? {
          id: message.id,
          excerpt: message.excerpt,
          user: {
            id: message.user.id,
            name: message.user.name,
            avatar_template: message.user.avatar_template,
            username: message.user.username,
          },
        }
      : null;
  }

  toJSON() {
    if (
      this.message?.length === 0 &&
      this.uploads?.length === 0 &&
      !this.replyToMsg
    ) {
      return null;
    }

    const data = {};

    if (this.uploads?.length > 0) {
      data.uploads = this.uploads;
    }

    if (this.message?.length > 0) {
      data.message = this.message;
    }

    if (this.replyToMsg) {
      data.replyToMsg = this.replyToMsg;
    }

    return JSON.stringify(data);
  }
}
