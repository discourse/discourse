import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";
import { i18n } from "discourse/lib/computed";

export default RestModel.extend({
  isPM: function() {
    const actionType = this.get("action_type");
    return (
      actionType === UserAction.TYPES.messages_sent ||
      actionType === UserAction.TYPES.messages_received
    );
  }.property("action_type"),

  description: i18n("action_type", "user_action_groups.%@"),

  isResponse: function() {
    const actionType = this.get("action_type");
    return (
      actionType === UserAction.TYPES.replies ||
      actionType === UserAction.TYPES.quotes
    );
  }.property("action_type")
});
