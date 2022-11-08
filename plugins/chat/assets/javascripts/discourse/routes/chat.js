import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { scrollTop } from "discourse/mixins/scroll-top";
import { schedule } from "@ember/runloop";
import { DRAFT_CHANNEL_VIEW } from "discourse/plugins/chat/discourse/services/chat";

export default class ChatRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service fullPageChat;
  @service chatPreferredMode;

  titleToken() {
    return I18n.t("chat.title_capitalized");
  }

  beforeModel(transition) {
    if (
      transition.from && // don't intercept when directly loading chat
      this.chatPreferredMode.isDrawer
    ) {
      if (transition.intent?.name === "chat.channel") {
        transition.abort();
        const id = transition.intent.contexts[0];
        return this.chat.getChannelBy("id", id).then((channel) => {
          this.appEvents.trigger("chat:open-channel", channel);
        });
      }

      if (transition.intent?.name === "chat.draft-channel") {
        transition.abort();
        this.appEvents.trigger("chat:open-view", DRAFT_CHANNEL_VIEW);
        return;
      }
    }

    if (!this.chat.userCanChat) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }

    this.fullPageChat.enter(this.router.currentURL);
  }

  activate() {
    this.chat.updatePresence();

    schedule("afterRender", () => {
      document.body.classList.add("has-full-page-chat");
      document.documentElement.classList.add("has-full-page-chat");
    });
  }

  deactivate() {
    this.fullPageChat.exit();
    this.chat.setActiveChannel(null);

    schedule("afterRender", () => {
      document.body.classList.remove("has-full-page-chat");
      document.documentElement.classList.remove("has-full-page-chat");
      scrollTop();
    });
  }
}
