import Component from "@glimmer/component";
import ChatThread from "discourse/plugins/chat/discourse/models/chat-thread";
import I18n from "I18n";

export default class ChatUploadDropZone extends Component {
  get title() {
    if (this.#isThread()) {
      return I18n.t("chat.upload_to_thread");
    } else {
      return I18n.t("chat.upload_to_channel", {
        title: this.args.model.title,
      });
    }
  }

  #isThread() {
    return this.args.model instanceof ChatThread;
  }
}
