import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { scrollTop } from "discourse/mixins/scroll-top";
import { schedule } from "@ember/runloop";

export default class ChatRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service fullPageChat;

  titleToken() {
    return I18n.t("chat.title_capitalized");
  }

  beforeModel(transition) {
    if (!this.chat.userCanChat) {
      return this.transitionTo(`discovery.${defaultHomepage()}`);
    }

    this.fullPageChat.enter(transition?.from);
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
