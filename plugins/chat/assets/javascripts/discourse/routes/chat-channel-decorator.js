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
      this.chat.setActiveChannel(model);

      const { messageId } = this.paramsFor(this.routeName);

      // messageId query param backwards-compatibility
      if (messageId) {
        this.router.replaceWith(
          "chat.channel",
          ...model.routeModels,
          messageId
        );
      }

      const { channelTitle } = this.paramsFor("chat.channel");
      if (channelTitle && channelTitle !== model.slugifiedTitle) {
        this.router.replaceWith("chat.channel", ...model.routeModels);
      }
    }
  };
}
