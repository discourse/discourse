import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { scrollTop } from "discourse/mixins/scroll-top";
import { schedule } from "@ember/runloop";

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
      "chat.channel",
      "chat.channel.thread",
      "chat.channel.threads",
      "chat.channel.index",
      "chat.channel.near-message",
      "chat.channel-legacy",
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

      let url = transition.intent.url;
      if (transition.targetName.startsWith("chat.channel")) {
        url ??= this.router.urlFor(
          transition.targetName,
          ...transition.intent.contexts
        );
      } else {
        url ??= this.router.urlFor(transition.targetName);
      }

      this.appEvents.trigger("chat:open-url", url);
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

  deactivate(transition) {
    if (transition) {
      const url = this.router.urlFor(transition.from.name);
      this.chatStateManager.storeChatURL(url);
    }

    this.chat.activeChannel = null;
    this.chat.updatePresence();

    schedule("afterRender", () => {
      document.body.classList.remove("has-full-page-chat");
      document.documentElement.classList.remove("has-full-page-chat");
      scrollTop();
    });
  }
}
