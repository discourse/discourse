import Component from "@glimmer/component";
import { getOwner } from "discourse-common/lib/get-owner";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import ChatMessageActions from "discourse/plugins/chat/discourse/lib/chat-message-actions";
import ChatThreadLivePanel from "discourse/plugins/chat/discourse/lib/chat-thread-live-panel";

export default class ChatThread extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;

  livePanel = null;
  messageActionsHandler = null;

  constructor() {
    super(...arguments);

    this.livePanel = new ChatThreadLivePanel(getOwner(this));
    this.messageActionsHandler = new ChatMessageActions(
      this.livePanel,
      this.currentUser
    );
  }

  get thread() {
    return this.chat.activeChannel.activeThread;
  }

  get title() {
    if (this.thread.title) {
      this.thread.escapedTitle;
    }

    return I18n.t("chat.threads.op_said");
  }
}
