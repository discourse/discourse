import ChatComposer from "../../chat-composer";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ChatComposerThread extends ChatComposer {
  @service("chat-channel-thread-composer") composer;
  @service("chat-channel-thread-pane") pane;

  context = "thread";

  composerId = "thread-composer";

  get placeholder() {
    return I18n.t("chat.placeholder_thread");
  }
}
