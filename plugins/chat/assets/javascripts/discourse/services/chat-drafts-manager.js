import Service from "@ember/service";

export default class ChatDraftsManager extends Service {
  drafts = {};

  add(message) {
    this.drafts[message.channel.id] = message;
  }

  get({ channelId }) {
    return this.drafts[channelId];
  }

  remove({ channelId }) {
    delete this.drafts[channelId];
  }
}
