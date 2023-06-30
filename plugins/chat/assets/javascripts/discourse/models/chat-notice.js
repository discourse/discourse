import { tracked } from "@glimmer/tracking";

export default class ChatNotice {
  static create(args = {}) {
    return new ChatNotice(args);
  }

  @tracked chatChannelId;
  @tracked textContent;

  constructor(args = {}) {
    this.chatChannelId = args.chat_channel_id;
    this.textContent = args.text_content;
  }
}
