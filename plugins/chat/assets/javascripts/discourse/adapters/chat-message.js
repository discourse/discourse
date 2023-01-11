import RESTAdapter from "discourse/adapters/rest";

export default class ChatMessage extends RESTAdapter {
  pathFor(store, type, findArgs) {
    if (findArgs.targetMessageId) {
      return `/chat/lookup/${findArgs.targetMessageId}.json?chat_channel_id=${findArgs.channelId}`;
    }

    let path = `/chat/${findArgs.channelId}/messages.json?page_size=${findArgs.pageSize}`;
    if (findArgs.messageId) {
      path += `&message_id=${findArgs.messageId}`;
    }
    if (findArgs.direction) {
      path += `&direction=${findArgs.direction}`;
    }
    return path;
  }

  apiNameFor() {
    return "chat-message";
  }
}
