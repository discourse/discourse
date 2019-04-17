import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";
import { i18n } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default RestModel.extend({
  @computed("action_type")
  isPM(actionType) {
    return (
      actionType === UserAction.TYPES.messages_sent ||
      actionType === UserAction.TYPES.messages_received
    );
  },

  description: i18n("action_type", "user_action_groups.%@"),

  @computed("action_type")
  isResponse(actionType) {
    return (
      actionType === UserAction.TYPES.replies ||
      actionType === UserAction.TYPES.quotes
    );
  }
});
