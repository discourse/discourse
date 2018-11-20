import computed from "ember-addons/ember-computed-decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  @computed("action")
  actionTitle(action) {
    return I18n.t(`group_histories.actions.${action}`);
  }
});
