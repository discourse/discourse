import { service } from "@ember/service";

export default function withChatChannel(extendedClass) {
  return class WithChatChannel extends extendedClass {
    @service chatChannelsManager;
    @service chat;
    @service router;

    async model(params) {
      return this.chatChannelsManager.find(params.channelId);
    }

    titleToken() {
      if (!this.currentModel) {
        return;
      }

      const title = this.currentModel.unicodeTitle || this.currentModel.title;

      if (this.currentModel.isDirectMessageChannel) {
        return `${title}`;
      } else {
        return `#${title}`;
      }
    }

    afterModel(model) {
      super.afterModel?.(...arguments);

      this.chat.activeChannel = model;

      if (!model) {
        return this.router.replaceWith("chat");
      }

      let { channelTitle } = this.paramsFor(this.routeName);

      if (channelTitle && channelTitle !== model.slugifiedTitle) {
        if (this.routeName === "chat.channel.info") {
          return this.router.replaceWith(
            "chat.channel.info",
            ...model.routeModels
          );
        }

        const messageId = this.paramsFor("chat.channel.near-message").messageId;
        const threadId = this.paramsFor("chat.channel.thread").threadId;

        if (threadId) {
          const threadMessageId = this.paramsFor(
            "chat.channel.thread.near-message"
          ).messageId;

          if (threadMessageId) {
            this.router.replaceWith(
              "chat.channel.thread.near-message",
              ...model.routeModels,
              threadId,
              threadMessageId
            );
          } else {
            this.router.replaceWith(
              "chat.channel.thread",
              ...model.routeModels,
              threadId
            );
          }
        } else if (messageId) {
          this.router.replaceWith(
            "chat.channel.near-message",
            ...model.routeModels,
            messageId
          );
        } else {
          this.router.replaceWith("chat.channel", ...model.routeModels);
        }
      } else {
        this.controllerFor("chat-channel").set("targetMessageId", null);
      }
    }
  };
}
