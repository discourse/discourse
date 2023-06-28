import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class ChatNotice {
  static create(args = {}) {
    return new ChatNotice(args);
  }

  @tracked chatMessageId;
  @tracked chatChannelId;
  @tracked title;
  @tracked description;

  constructor(args = {}) {
    this.chatMessageId = args.chat_message_id;
    this.chatChannelId = args.chat_channel_id;
    this.title = this._translatedText(args.title, args.translated_title);
    this.description = this._translatedText(
      args.description,
      args.translated_description
    );
  }

  _translatedText(translationKey, translated) {
    if (translated) {
      return translated;
    }

    if (translationKey) {
      return I18n.t(translationKey);
    }
  }
}
