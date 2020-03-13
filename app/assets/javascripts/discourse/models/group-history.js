import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  @discourseComputed("action")
  actionTitle(action) {
    return I18n.t(`group_histories.actions.${action}`);
  }
});
