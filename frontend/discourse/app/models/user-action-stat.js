import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";
import { i18n } from "discourse-i18n";

export default class UserActionStat extends RestModel {
  @computed("action_type")
  get description() {
    return i18n(`user_action_groups.${this.action_type}`);
  }

  @computed("action_type")
  get isPM() {
    return (
      this.action_type === UserAction.TYPES.messages_sent ||
      this.action_type === UserAction.TYPES.messages_received
    );
  }

  @computed("action_type")
  get isResponse() {
    return (
      this.action_type === UserAction.TYPES.replies ||
      this.action_type === UserAction.TYPES.quotes
    );
  }
}
