import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";

export default class ChatThreadListItem extends Component {
  @service currentUser;

  get title() {
    return (
      this.args.thread.title ||
      `${I18n.t("chat.thread.default_title", {
        thread_id: this.args.thread.id,
      })}`
    );
  }

  get canChangeThreadSettings() {
    return (
      this.currentUser.staff ||
      this.currentUser.id === this.args.thread.originalMessageUserId
    );
  }

  @action
  openThreadSettings() {}
}
