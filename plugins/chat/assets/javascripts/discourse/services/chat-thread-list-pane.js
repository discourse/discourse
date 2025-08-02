import Service, { service } from "@ember/service";

export default class ChatThreadListPane extends Service {
  @service chat;
  @service router;

  get isOpened() {
    return this.router.currentRoute.name === "chat.channel.threads";
  }

  async close() {
    await this.router.transitionTo(
      "chat.channel",
      ...this.chat.activeChannel.routeModels
    );
  }

  async open() {
    await this.router.transitionTo(
      "chat.channel.threads",
      ...this.chat.activeChannel.routeModels
    );
  }
}
