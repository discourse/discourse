import { i18n } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";

export default class UserActionStat extends RestModel {
  @i18n("action_type", "user_action_groups.%@") description;

  @discourseComputed("action_type")
  isPM(actionType) {
    return (
      actionType === UserAction.TYPES.messages_sent ||
      actionType === UserAction.TYPES.messages_received
    );
  }

  @discourseComputed("action_type")
  isResponse(actionType) {
    return (
      actionType === UserAction.TYPES.replies ||
      actionType === UserAction.TYPES.quotes
    );
  }
}
