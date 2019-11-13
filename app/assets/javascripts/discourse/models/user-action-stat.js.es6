import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";
import { i18n } from "discourse/lib/computed";

export default RestModel.extend({
  @discourseComputed("action_type")
  isPM(actionType) {
    return (
      actionType === UserAction.TYPES.messages_sent ||
      actionType === UserAction.TYPES.messages_received
    );
  },

  description: i18n("action_type", "user_action_groups.%@"),

  @discourseComputed("action_type")
  isResponse(actionType) {
    return (
      actionType === UserAction.TYPES.replies ||
      actionType === UserAction.TYPES.quotes
    );
  }
});
