import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class GroupHistory extends RestModel {
  @discourseComputed("action")
  actionTitle(action) {
    return i18n(`group_histories.actions.${action}`);
  }
}
