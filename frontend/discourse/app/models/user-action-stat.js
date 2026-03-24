import { computed } from "@ember/object";
import { i18n } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";

export default class UserActionStat extends RestModel {
  @i18n("action_type", "user_action_groups.%@") description;

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
