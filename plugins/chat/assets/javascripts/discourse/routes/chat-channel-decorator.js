import { inject as service } from "@ember/service";

export default function withChatChannel(extendedClass) {
  return class WithChatChannel extends extendedClass {
    @service chatChannelsManager;
    @service chat;
    @service router;

    async model(params) {
      return this.chatChannelsManager.find(params.channelId);
    }

    afterModel(model) {
      this.controllerFor("chat-channel").set("targetMessageId", null);
      this.chat.activeChannel = model;

      let { messageId, channelTitle } = this.paramsFor(this.routeName);

      // messageId query param backwards-compatibility
      if (messageId) {
        this.router.replaceWith(
          "chat.channel",
          ...model.routeModels,
          messageId
        );
      }

      if (channelTitle && channelTitle !== model.slugifiedTitle) {
        const nearMessageParams = this.paramsFor("chat.channel.near-message");
        if (nearMessageParams.messageId) {
          this.router.replaceWith(
            "chat.channel.near-message",
            ...model.routeModels,
            nearMessageParams.messageId
          );
        } else {
          this.router.replaceWith("chat.channel", ...model.routeModels);
        }
      }
    }
  };
}
