import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatComposerService from "discourse/plugins/chat/discourse/lib/chat-composer-service";

export default class ChatThreadComposer extends ChatComposerService {
  @service chat;
  @service site;

  @action
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    message.thread.draft = message;

    if (this.site.desktopView) {
      this.focus({ ensureAtEnd: true });
    }
  }

  @action
  replyTo(message) {
    this.chat.activeMessage = null;
    message.thread.draft.inReplyTo = message;

    if (this.site.desktopView) {
      this.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }
}
