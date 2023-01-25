import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { scrollTop } from "discourse/mixins/scroll-top";
import { schedule } from "@ember/runloop";
import { action } from "@ember/object";

export default class ChatRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service chatStateManager;

  titleToken() {
    return I18n.t("chat.title_capitalized");
  }

  beforeModel(transition) {
    if (!this.chat.userCanChat) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }

    const INTERCEPTABLE_ROUTES = [
      "chat.channel.index",
      "chat.channel",
      "chat.channel-legacy",
      "chat.channel.near-message",
      "chat",
      "chat.index",
      "chat.draft-channel",
    ];

    if (
      transition.from && // don't intercept when directly loading chat
      this.chatStateManager.isDrawerPreferred &&
      INTERCEPTABLE_ROUTES.includes(transition.targetName)
    ) {
      transition.abort();

      let URL = transition.intent.url;
      if (
        transition.targetName.startsWith("chat.channel") ||
        transition.targetName.startsWith("chat.channel-legacy")
      ) {
        URL ??= this.router.urlFor(
          transition.targetName,
          ...transition.intent.contexts
        );
      } else {
        URL ??= this.router.urlFor(transition.targetName);
      }

      this.appEvents.trigger("chat:open-url", URL);
      return;
    }

    this.appEvents.trigger("chat:toggle-close");
  }

  activate() {
    this.chatStateManager.storeAppURL();
    this.chat.updatePresence();

    schedule("afterRender", () => {
      document.body.classList.add("has-full-page-chat");
      document.documentElement.classList.add("has-full-page-chat");
    });
  }

  deactivate() {
    schedule("afterRender", () => {
      document.body.classList.remove("has-full-page-chat");
      document.documentElement.classList.remove("has-full-page-chat");
      scrollTop();
    });
  }

  @action
  willTransition(transition) {
    if (
      !transition?.to?.name?.startsWith("chat.channel") ||
      !transition?.to?.name?.startsWith("chat.channel.near-message")
    ) {
      this.chat.setActiveChannel(null);
    }

    if (!transition?.to?.name?.startsWith("chat.")) {
      this.chatStateManager.storeChatURL();
      this.chat.updatePresence();
    }
  }
}
