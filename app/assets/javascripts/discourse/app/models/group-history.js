import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class GroupHistory extends RestModel {
  @discourseComputed("action")
  actionTitle(action) {
    return I18n.t(`group_histories.actions.${action}`);
  }
}
