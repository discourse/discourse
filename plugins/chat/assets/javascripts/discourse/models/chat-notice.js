import { tracked } from "@glimmer/tracking";

export default class ChatNotice {
  static create(args = {}) {
    return new ChatNotice(args);
  }

  @tracked channelId;
  @tracked textContent;

  constructor(args = {}) {
    this.channelId = args.channel_id;
    this.textContent = args.text_content;
  }
}
