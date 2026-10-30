import Service, { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";

export default class LiveChatDrafts extends Service {
  @service currentUser;

  #drafts = new Map();
  #userId;

  get(roomId, channel) {
    const key = this.#key(roomId, channel.id);
    if (!this.#drafts.has(key)) {
      const ChatMessage = optionalRequire(
        "discourse/plugins/chat/discourse/models/chat-message"
      );
      this.#drafts.set(
        key,
        ChatMessage.createDraftMessage(channel, { user: this.currentUser })
      );
    }
    return this.#drafts.get(key);
  }

  clear(roomId, channelId) {
    this.#drafts.delete(this.#key(roomId, channelId));
  }

  #key(roomId, channelId) {
    if (this.#userId !== this.currentUser?.id) {
      this.#drafts.clear();
      this.#userId = this.currentUser?.id;
    }
    const key = `${roomId}:${channelId}`;
    for (const existing of this.#drafts.keys()) {
      if (existing.startsWith(`${roomId}:`) && existing !== key) {
        this.#drafts.delete(existing);
      }
    }
    return key;
  }
}
