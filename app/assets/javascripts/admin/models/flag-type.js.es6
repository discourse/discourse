import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  @discourseComputed("id")
  name(id) {
    return I18n.t(`admin.flags.summary.action_type_${id}`, { count: 1 });
  }
});
