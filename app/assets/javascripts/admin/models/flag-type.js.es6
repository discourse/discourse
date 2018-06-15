import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";

export default RestModel.extend({
  @computed("id")
  name(id) {
    return I18n.t(`admin.flags.summary.action_type_${id}`, { count: 1 });
  }
});
